# Traefik

HTTPS-first reverse proxy and ingress controller for the entire cluster.
Auto-discovers services via Consul Catalog, terminates TLS using wildcard
certificates from Let's Encrypt (ACME with Cloudflare DNS challenge), and
defines all shared middleware chains (oauth2-proxy, security headers, rate
limiting, Umami analytics injection). Every HTTP-accessible service in the
cluster routes through Traefik.

## Architecture

Runs as a system job on ingress-role nodes (goren and nomad-client-05) with
host networking on static ports. Keepalived manages VIP 192.168.68.50 for
DNS-based failover between the two instances. Each instance independently
obtains and renews wildcard certificates for `munchbox.cc` and `*.munchbox.cc`
via ACME, persisted locally at `/opt/traefik/acme/acme.json`.

The static configuration defines entrypoints and provider settings. The
dynamic configuration (file provider) defines routers, middlewares, and
services for infrastructure UIs that are not registered in Consul (Consul,
Nomad, Vault, Proxmox, ZFS Watcher). All other services register themselves
via Consul Catalog tags in their own job definitions.

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
(port 443). Keepalived manages the VIP (192.168.68.50) that DNS points to.

Traefik routes requests based on Host headers and path rules. Consul Catalog
provider refreshes service discovery every 5s. Services opt in to Traefik
routing via `traefik.enable=true` in their Consul tags.

TLS certificates are managed by Traefik's built-in ACME resolver using the
Cloudflare DNS-01 challenge. The `defaultGeneratedCert` in the dynamic
configuration ensures all `*.munchbox.cc` routes use the ACME-issued wildcard.

## Failure Modes

- **Single node failure**: Keepalived fails over the VIP to the surviving
  ingress node within approximately six seconds. Brief blip during ARP
  propagation, then traffic resumes on the backup.
- **Traefik crash**: Keepalived health check detects the failure and demotes
  the node's VRRP priority, triggering VIP failover to the healthy node.
- **Consul unavailable**: Consul Catalog services become unroutable.
  File-provider services (Nomad, Consul, Vault, Proxmox) continue working.

## Dependencies

**Requires:**
- Consul (service discovery via Catalog provider)
- Vault (Consul token, Cloudflare API token, Nomad UI token)
- Keepalived (VIP for DNS)
- OAuth2-Proxy (forward auth for authenticated services)

**Required by:**
- Every HTTP-accessible service in the cluster

## Notable Configuration

- System job constrained to `meta.role = "ingress"` with `max_parallel = 1`
  for rolling updates with zero downtime
- Priority 90 (highest in the cluster after system services) ensures Traefik
  starts before any services that depend on HTTP routing
- The rewritebody plugin injects CSS (Vault theme, Umami analytics) into
  HTML responses without modifying upstream services
- Separate serversTransports for Nomad (TLS with CA verification, extended
  timeouts for websockets) and Proxmox/Vault (insecure skip verify)
- Per-service rate limiting uses CF-Connecting-IP header to rate-limit by
  real client IP rather than the tunnel's IP
