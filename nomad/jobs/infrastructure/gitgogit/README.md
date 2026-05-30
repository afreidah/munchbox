# gitgogit

Daemon that mirrors a fixed list of GitHub repositories into the local
Forgejo instance on a 30-minute interval, with a small web dashboard
for status and manual sync triggers.

## Image

`registry.munchbox.cc/gitgogit:v0.2.0`

## Hostname / exposure

- `gitgogit.munchbox.cc`
- HTTPS through `oauth2-proxy-errors@file,oauth2-proxy@file`
- HTTP variant adds `cf-tunnel-https@file` for the Cloudflare tunnel

## Placement

- `node_pool = all`, single instance
- Excluded from `oraclenode1` and `oraclenode2` (kept on the LAN side)

## Dependencies

- Forgejo at `forgejo.service.consul:30028` (push target)
- Vault path `secret/data/forgejo` for `api_token` used as the
  Forgejo push credential

## Notable configuration

- Mirrors munchbox, s3-orchestrator, gitgogit, flight-fetcher,
  cloudflare-log-collector, oracle-watchdog, nomad-temporal-jobs,
  health-checker, and g3 into `alex/<name>` on Forgejo
- `push_strategy: branches+tags`, `force: true` on every mirror
- Daemon interval 30m; dashboard listens on container :8080
- Healthcheck on `/healthz`
