# nextcloud

Self-hosted cloud storage and collaboration. File sync, sharing, web doc
management. Uses the shared Postgres + Redis infrastructure.

## Image

`nextcloud:33.0-apache` (main + cron sidecar share the image)

## Hostname / exposure

- `nextcloud.munchbox.cc`
- Four routers (priorities 10/20) split across HTTPS + HTTP entrypoints:
  - `/ocs`, `/remote.php`, `/public.php`, `/status.php` -- API/sync paths,
    bypass oauth2-proxy (clients auth directly with Nextcloud)
  - catch-all web UI -- gated by `oauth2-proxy@file`
- All routers get `nextcloud-ratelimit@file` + `nextcloud-sec@file`
- Bridge mode; mapped static port 18081 -> container 80

## Placement

- Pinned to `goren` (`node.unique.name = goren`) for gdrive NFS access
- `count = 1`

## Dependencies

- Postgres `nextcloud` DB via `haproxy-postgres.service.consul:5433`
- Redis (file locking + session cache) via `haproxy-redis.service.consul:6380`
- Vault for DB / Redis credentials
- gdrive NFS host volume `/mnt/gdrive/nextcloud/data` for user data; config +
  apps on local storage
- oauth2-proxy (web UI only)

## Notable configuration

- Two-task group: `nextcloud` (main) + `cron` poststart sidecar runs the
  background job loop
- Bridge-mode DNS pointed at node IP + `var.pihole_1`/`var.pihole_2`
- task_states health check (HTTP probe is disabled to survive setup
  migrations on first boot)
