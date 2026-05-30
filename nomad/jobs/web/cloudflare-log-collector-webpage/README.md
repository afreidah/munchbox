# cloudflare-log-collector-webpage

Static Hugo project site for cloudflare-log-collector. Separate from
the collector daemon itself, which lives in
`monitoring/cloudflare-log-collector`.

## Image

`registry.munchbox.cc/cloudflare-log-collector-web:v0.1.15`

## Hostname / exposure

- `cloudflare-log-collector.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `cloudflare-log-collector-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true` -- one
  replica per node for HA behind traefik
- Munchbox-service pack job (`.hcl`), `size = tiny`

## Dependencies

- None -- static site, no Vault, no database

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
