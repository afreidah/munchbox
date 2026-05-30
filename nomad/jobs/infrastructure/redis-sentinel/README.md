# redis-sentinel

HA Redis cluster (2 servers + 3 Sentinels) with automatic failover.
Provides cache, session, and queue storage for Nextcloud, Forgejo, Immich,
Trivy Server, etc.

## Image

- `redis:8-alpine` (redis server + sentinel)
- `oliver006/redis_exporter:v1.80.1` (metrics sidecar)
- `busybox:1.37.0` (prestart init-storage)

## Hostname / exposure

- All Consul services tagged `traefik.enable=false`; internal-only
- Static ports: redis 6379, sentinel 26379, exporter 9121
- Clients connect via `haproxy-redis.service.consul:6380`; HAProxy uses
  `INFO replication` checks to track the current master

## Placement

- `redis` group, `count = 2`: spread across distinct hosts, restricted to
  `stabler,goren,nomad-server-03,nomad-client-01..05` (whitelist excludes
  Oracle nodes -- WG tunnel latency is too high for a latency-sensitive
  data store)
- `sentinel-quorum` group, `count = 1`: pinned to `nomad-client-04` (needs
  Consul ACL access for service queries)
- Host networking so Consul DNS-resolved addresses are routable from
  bridge-mode containers

## Dependencies

- Vault `secret/data/redis-shared` (Redis auth password)
- Consul (service discovery for primary, plus quorum sentinel resolution)
- HAProxy fronts traffic on 6380

## Notable configuration

- All instances start standalone; Sentinel manages topology and persists via
  `CONFIG REWRITE` -- no hard-coded master/replica in Nomad templates
- Quorum 2 of 3 with `down-after-milliseconds 5s`, failover-timeout 60s,
  `parallel-syncs 1`
- 512 MiB cap with `noeviction` -- writes fail instead of silently evicting
- Persistence: RDB (60s/1 key) + AOF everysec
- init-storage task wipes stale `sentinel.conf` on every start to avoid
  cross-allocation master leakage
- Priority 80 so Redis comes up before app services
