# lidarr

Music collection manager in the *arr stack. Watches indexers via Prowlarr and
hands grabs off to Deluge.

## Image

`linuxserver/lidarr:3.1.0`

## Hostname / exposure

- `lidarr.munchbox.cc`
- HTTPS router gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel

## Placement

- Constraint: `meta.gpu = true`
- Host-networked on static port 8686; co-located with the rest of the *arr
  stack on the media node

## Dependencies

- Postgres via `haproxy-postgres.service.consul:5433`, databases
  `lidarr_main` and `lidarr_log`
- Vault for Postgres credentials (templated into `secrets/postgres.env`)
- theme-server (`http://themes.munchbox.cc/css/lidarr.css`) via theme.park
  DOCKER_MODS
- Host volume `/tank` mounted at `/data`
- Local `/config` owned by `1001:1001`

## Notable configuration

- Health probe `/ping` to avoid auth-failure log spam
- PUID/PGID 1001 to match the media UID on `/tank`
