# radarr

Movie manager in the *arr stack. Watches indexers via Prowlarr and hands
grabs off to Deluge.

## Image

`linuxserver/radarr:6.1.1`

## Hostname / exposure

- `radarr.munchbox.cc`
- HTTPS router gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel

## Placement

- Constraint: `meta.gpu = true`
- Static port 7878 (not host-networked)

## Dependencies

- Postgres via `haproxy-postgres.service.consul:5433`, databases
  `radarr_main` and `radarr_log`
- Vault for Postgres credentials (templated into `secrets/postgres.env`)
- theme-server (`http://themes.munchbox.cc/css/radarr.css`) via theme.park
  DOCKER_MODS
- Host volume `/tank` mounted at `/data`
- Local `/config` owned by `1001:1001`

## Notable configuration

- Health probe `/ping`
- PUID/PGID 1001
- 160 MiB memory reservation
