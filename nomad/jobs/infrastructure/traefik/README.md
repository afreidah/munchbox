# Traefik

HTTPS-first reverse proxy and ingress controller for the entire cluster.
Auto-discovers services via Consul Catalog, terminates TLS using wildcard
certificates from Let's Encrypt (managed by the certbot job), and defines
all shared middleware chains (oauth2-proxy, security headers, rate limiting,
Umami analytics injection). Every HTTP-accessible service in the cluster
routes through Traefik.

## Architecture

Single-instance service on the ingress node (goren) using host networking
with static ports. The static configuration defines entrypoints and provider
settings. The dynamic configuration (file provider) defines routers,
middlewares, and services for infrastructure UIs that are not registered in
Consul (Consul, Nomad, Vault, Proxmox, ZFS Watcher). All other services
register themselves via Consul Catalog tags in their own job definitions.

Two traffic paths exist: direct HTTPS from the LAN, and HTTP from the
Cloudflare tunnel (cloudflared-tunnel job). The `cf-tunnel-https` middleware
sets `X-Forwarded-Proto: https` on tunnel traffic so services behave as if
the connection is encrypted end-to-end.

## Components

| Task | Role | Lifecycle |
|------|------|-----------|
| geoip-updater | Downloads MaxMind GeoLite2 databases for geo analytics | prestart |
| traefik | Reverse proxy, TLS termination, routing | main |
| traefik-log-filter | Filters Nomad blocking queries from access logs | poststart sidecar |
| traefik-log-agent | Parses access logs, exposes metrics API | poststart sidecar |
| traefik-log-dashboard | Web UI for traffic analytics at traefik-logs.munchbox.cc | poststart sidecar |

The log pipeline flows: traefik writes JSON access logs, log-filter strips
noisy long-poll connections, log-agent parses the filtered logs, and
log-dashboard presents the analytics. GeoIP data from the prestart task is
shared via the alloc directory.

## Data Flow

External traffic: Internet -> Cloudflare -> cloudflared tunnel -> Traefik
HTTP entrypoint (port 80). LAN traffic: Client -> Traefik HTTPS entrypoint
(port 443). Keepalived manages the VIP (192.168.68.60) that DNS points to.

Traefik routes requests based on Host headers and path rules. Consul Catalog
provider refreshes service discovery every 5s. Services opt in to Traefik
routing via `traefik.enable=true` in their Consul tags.

TLS certificates are loaded from files on an NFS mount, managed by the
certbot job. The ACME resolver in the config exists only for backward
compatibility with Consul Catalog service tags that reference it.

## Failure Modes

- **Traefik crash**: All HTTP traffic stops. Nomad restarts within 15s
  (restart policy). Brief downtime is expected since there is only one
  ingress node.
- **Cert expiry**: Certbot job renews certificates on the NFS mount.
  Traefik reads certs at startup; a job restart picks up renewed certs.
- **Consul unavailable**: Consul Catalog services become unroutable.
  File-provider services (Nomad, Consul, Vault, Proxmox) continue working.

## Dependencies

**Requires:**
- Certbot (TLS certificates on NFS mount)
- Consul (service discovery via Catalog provider)
- Vault (Consul token, Cloudflare API token, Nomad UI token)
- Keepalived (VIP for DNS)
- OAuth2-Proxy (forward auth for authenticated services)

**Required by:**
- Every HTTP-accessible service in the cluster

## Notable Configuration

- Priority 90 (highest in the cluster after system services) ensures Traefik
  starts before any services that depend on HTTP routing
- The rewritebody plugin injects CSS (Vault theme, Umami analytics) into
  HTML responses without modifying upstream services
- Separate serversTransports for Nomad (TLS with CA verification, extended
  timeouts for websockets) and Proxmox/Vault (insecure skip verify)
- Per-service rate limiting uses CF-Connecting-IP header to rate-limit by
  real client IP rather than the tunnel's IP
