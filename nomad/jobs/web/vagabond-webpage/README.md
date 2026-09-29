# vagabond-webpage

Static Hugo project site for Vagabond, built from `web/` in the vagabond
repository.

## Image

`registry.munchbox.cc/vagabond-web:dev`

## Hostname / exposure

- `vagabond.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `vagabond-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
