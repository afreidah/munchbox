# prowlarr

Indexer aggregator for the *arr stack. Syncs indexer definitions out to
sonarr, radarr, lidarr, and readarr.

## Image

`linuxserver/prowlarr:2.3.5`

## Hostname / exposure

- `prowlarr.munchbox.cc`
- HTTPS router gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel

## Placement

- Constraint: `meta.gpu = true`
- Host-networked on static port 9696

## Dependencies

- Postgres via `haproxy-postgres.service.consul:5433`, databases
  `prowlarr_main` and `prowlarr_log`
- Vault for Postgres credentials (templated into `secrets/postgres.env`)
- theme-server CSS (`http://themes.munchbox.cc/css/prowlarr.css`) via
  theme.park DOCKER_MODS
- FlareSolverr (optional) for Cloudflare-protected indexers

## Notable configuration

- Health probe `/ping`
- PUID/PGID 1001
- 300 MiB / 1000 MHz reservation
