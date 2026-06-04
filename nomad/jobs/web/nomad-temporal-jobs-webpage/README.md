# nomad-temporal-jobs-webpage

Static Hugo project site for the nomad-temporal-jobs repo (the
Temporal worker images used by backup-worker, cleanup-worker, and
trivy-scan-worker).

## Image

`registry.munchbox.cc/temporal-workers-web:v0.2.6`

## Hostname / exposure

- `nomad-temporal-jobs.munchbox.cc`
- Traefik router on the `web` entrypoint (HTTP only), no oauth2-proxy
- Reached publicly via the Cloudflare tunnel
- Router priority 100, service `nomad-temporal-jobs-webpage`

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`
- Excluded from `oraclenode1` and `oraclenode2`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
