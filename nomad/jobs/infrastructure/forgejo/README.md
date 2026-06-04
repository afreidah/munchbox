# forgejo

Self-hosted Git service with push mirroring to GitHub and an integrated Actions
runner. All munchbox infra/app code lives here.

## Image

`codeberg.org/forgejo/forgejo:15.0.2` (plus `busybox:1.38.0` for the prestart
init-config task)

## Hostname / exposure

- `git.munchbox.cc`
- Six Traefik routers in total, split across HTTPS (`websecure`) and HTTP
  (`web`, for the Cloudflare tunnel):
  - `forgejo-api` / `forgejo-api-http` -- `PathPrefix(/api/)`, no oauth2-proxy,
    priority 10, rate-limited
  - `forgejo-git` / `forgejo-git-http` -- `PathRegexp(/.+\.git/.*)`, no
    oauth2-proxy, priority 10
  - `forgejo` / `forgejo-http` -- catch-all web UI gated by `oauth2-proxy@file`
- SSH on static host port 2222 (Consul service `forgejo-ssh`,
  `traefik.enable=false`)

## Placement

- Pinned to `stabler` (`node.unique.name = stabler`) for the gdrive NFS mount
- Bridge networking; static host port 2222 prevents canaries (rolling only)

## Dependencies

- Postgres `forgejo` via `haproxy-postgres.service.consul:5433`
- Redis (cache / session / queue) via
  `haproxy-redis.service.consul:6380` db 2
- Vault `secret/data/forgejo` (LFS JWT, DB creds, secret/internal tokens,
  oauth2 JWT) and `secret/data/redis-shared`
- gdrive NFS host volume `/mnt/gdrive/forgejo` -> `/data`
- Tempo OTLP `tempo.service.consul:4317`
- oauth2-proxy (web UI only)

## Notable configuration

- Prestart `init-config` (busybox) renders `app.ini` from Vault, chowns
  `/data/gitea` to 1000:1000, then exits
- Push mirroring enabled, 8h default interval
- Webhook `ALLOWED_HOST_LIST` = `loopback,*.service.consul,*.munchbox.cc`
  (SSRF guard)
- Bridge-mode DNS pointed at node IP + `var.pihole_1`/`var.pihole_2`
