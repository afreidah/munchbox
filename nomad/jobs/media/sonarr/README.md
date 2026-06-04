# sonarr

TV-show manager in the *arr stack. Watches indexers via Prowlarr and hands
grabs off to Deluge.

## Image

`linuxserver/sonarr:4.0.17`

## Hostname / exposure

- `sonarr.munchbox.cc`
- HTTPS router gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel

## Placement

- Constraint: `meta.gpu = true`
- Host-networked on static port 8989

## Dependencies

- Postgres via `haproxy-postgres.service.consul:5433`, databases
  `sonarr_main` and `sonarr_log`
- Vault for Postgres credentials (templated into `secrets/postgres.env`)
- theme-server (`http://themes.munchbox.cc/css/sonarr.css`) via theme.park
  DOCKER_MODS
- Host volume `/tank` mounted at `/data`
- Local `/config` owned by `1001:1001`

## Notable configuration

- Health probe `/ping`
- PUID/PGID 1001
- 1000 MHz CPU reservation
