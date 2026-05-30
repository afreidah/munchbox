# s3-orchestrator-webpage

Static Hugo project site for s3-orchestrator. Separate from the
running gateway (`infrastructure/s3-orchestrator`); the live admin
UI for the gateway lives behind `s3.munchbox.cc`, not this site.

## Image

`registry.munchbox.cc/s3-orchestrator-web:v0.60.22`

## Hostname / exposure

- `s3-orchestrator.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `s3-orchestrator-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
