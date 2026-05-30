# oracle-watchdog-webpage

Static Hugo project site for oracle-watchdog (the systemd monitor
running on Oracle Cloud nodes).

## Image

`registry.munchbox.cc/oracle-watchdog-web:v1.3.0`

## Hostname / exposure

- `oracle-watchdog.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `oracle-watchdog-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
