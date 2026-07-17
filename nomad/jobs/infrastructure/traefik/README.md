# traefik

HTTPS-first reverse proxy and ingress controller. Auto-discovers services
via Consul Catalog, terminates TLS using Let's Encrypt wildcards (Cloudflare
DNS-01), and owns all shared middleware chains (oauth2-proxy, security
headers, rate limiting, Umami analytics injection). Every HTTP-accessible
service in the cluster routes through here.

## Image

- traefik: `traefik:v3.7.5`
- geoip-updater: `maxmindinc/geoipupdate:v7`
- traefik-log-filter: `busybox:1.38.0`
- traefik-log-agent: `hhftechnology/traefik-log-dashboard-agent:3.1.1`
- traefik-log-dashboard: `hhftechnology/traefik-log-dashboard:3.1.1`
- cloudflared-tunnel: `cloudflare/cloudflared:2026.7.1`

## Hostname / exposure

- Multiple Consul-tagged routers per upstream; file-provider routers for
  Consul, Nomad, Vault, Proxmox, ZFS Watcher
- `traefik-logs.munchbox.cc` -- log-dashboard UI
- ACME wildcard for `munchbox.cc` and `*.munchbox.cc`

## Placement

- System job, `constraint meta.role = ingress` (goren, nomad-client-05)
- Host networking, static 80/443; `max_parallel = 1`, priority 90
- ACME state persists at `/opt/traefik/acme/acme.json` per node

## Dependencies

- Consul (Catalog provider, refresh 5s) + Vault (Consul token, Cloudflare
  API token, Nomad UI token)
- Keepalived (VIP `192.168.68.50`)
- OAuth2-Proxy (forward auth middleware)
- Cloudflare API (DNS-01 challenge)

## Notable configuration

- Six tasks in one group:
  - `geoip-updater` (prestart) -- pulls MaxMind GeoLite2 into the alloc dir
  - `traefik` (main)
  - `traefik-log-filter` (poststart sidecar) -- strips Nomad long-poll noise
  - `traefik-log-agent` (poststart sidecar) -- parses access logs, exposes
    metrics API
  - `traefik-log-dashboard` (poststart sidecar) -- analytics UI
  - `cloudflared-tunnel` (poststart sidecar) -- Cloudflare tunnel connector
    runs alongside Traefik so its lifecycle tracks ingress, not a separate
    job
- `cf-tunnel-https` middleware sets `X-Forwarded-Proto: https` on tunnel
  traffic so services behave as if the connection is TLS end-to-end
- `rewritebody` plugin injects Vault CSS theme + Umami analytics into HTML
- Separate serversTransports: Nomad uses TLS-with-CA + long timeouts for
  websockets; Proxmox / Vault use insecure-skip-verify
- Per-service rate limit uses `CF-Connecting-IP` for real-client IP
