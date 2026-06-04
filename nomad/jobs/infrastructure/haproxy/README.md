# haproxy

TCP failover proxy in front of Patroni (PostgreSQL) and Redis Sentinel.
Health-checks Patroni's REST API for the primary and Redis's `info replication`
for `role:master`, and uses `on-marked-down shutdown-sessions` to kill stale
connections on failover so apps reconnect to the new primary.

## image

`haproxy:3.2-alpine`

## hostname / exposure

- `haproxy-postgres` (TCP `5433`) and `haproxy-redis` (TCP `6380`) -- both
  internal-only, `traefik.enable=false`
- `haproxy-stats` on `haproxy.munchbox.cc`, behind
  `oauth2-proxy-errors@file,oauth2-proxy@file` (plus `cf-tunnel-https@file`
  on the HTTP entrypoint)
- `haproxy-metrics` on the same `:8405` port, scraped by Prometheus at `/metrics`

## placement

- constraint: `node.unique.name set_contains_any stabler,nomad-client-05`
- co-located with Patroni; `count = 2`, `distinct_hosts`, spread by node name
- host networking with static ports `5433`, `6380`, `8405`

## dependencies

- Patroni REST API on `:8008` (`option httpchk GET /primary`)
- Redis on `redis.service.consul:6379` (auth + `info replication` check)
- Consul DNS at `127.0.0.1:8600` for backend resolution via `server-template`
- Vault `secret/data/redis-shared` for the Redis AUTH password used in the
  TCP health check

## notable configuration

- backends are NOT hardcoded -- HAProxy uses its own Consul DNS resolver
  against `patroni.service.consul` and `redis.service.consul`, sidestepping
  Nomad's per-task Consul SI token scoping
- Prometheus exporter is served from the same `:8405` socket via
  `http-request use-service prometheus-exporter if { path /metrics }`
- `change_mode = restart` on the config template -- any Consul DNS or Vault
  password rotation triggers a reload
