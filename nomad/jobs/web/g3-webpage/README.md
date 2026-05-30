# g3-webpage

Static Hugo project site for g3. Separate from the running daemon
(`infrastructure/g3-proxy`).

## Image

`registry.munchbox.cc/g3-web:v0.5.1`

## Hostname / exposure

- `g3.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `g3-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
