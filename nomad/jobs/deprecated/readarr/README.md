# readarr

Book and audiobook manager in the *arr stack. Pairs with Kavita for reading.

## Image

`linuxserver/readarr:0.4.19-nightly`

## Hostname / exposure

- `readarr.munchbox.cc`
- HTTPS router gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel

## Placement

- Constraint: `meta.gpu = true`
- Static port 8787 (not host-networked)

## Dependencies

- Postgres via `haproxy-postgres.service.consul:5433`, databases
  `readarr_main` and `readarr_log`
- Vault for Postgres credentials (templated into `secrets/postgres.env`)
- theme-server (`http://themes.munchbox.cc/css/readarr.css`) via theme.park
  DOCKER_MODS
- Host volumes: `/tank` -> `/data`, `/mnt/gdrive-secondary/Books` -> `/books`
- Local `/config` owned by `1001:1001`

## Notable configuration

- Health probe `/ping`
- PUID/PGID 1001
- 192 MiB memory reservation
- Nightly tag pinned because there is no stable release stream
