# patroni

High-availability PostgreSQL 18 cluster. Patroni handles leader election via
Consul, streams WAL between instances, and exposes a REST API on `:8008` that
HAProxy uses to find the current primary.

## image

`registry.munchbox.cc/patroni:pg18`
(sidecar exporter: `quay.io/prometheuscommunity/postgres-exporter:v0.18.1`)

## hostname / exposure

- internal-only, no traefik
- Consul services: `postgres-primary`, `postgres-replica`, `patroni`,
  plus a metrics service for the postgres_exporter sidecar
- apps do not talk to these services directly -- they go through
  `haproxy-postgres.service.consul:5433`

## placement

- constraint: `node.unique.name set_contains_any stabler,nomad-client-05`
- `count = 2`, `distinct_hosts`, spread by node name
- host networking with static ports `5432` (postgres), `8008` (Patroni REST),
  `9187` (exporter)
- alloc data lives at `/opt/nomad/data/patroni-${NOMAD_ALLOC_INDEX}` on the host

## dependencies

- Consul at `consul.service.consul:8500` for DCS / leader election
  (Patroni token from Vault `secret/data/patroni`)
- Vault PKI role `pki_int/issue/postgres` for server TLS, TTL `2160h`,
  SANs include `haproxy-postgres.service.consul`
- Vault `secret/data/postgres-shared/root` and `.../replication` for
  superuser and replication accounts
- per-database creds from Vault for bootstrap: `nextcloud`, `temporal`,
  `forgejo`, `umami`, `trivy-dashboard`, `grafana`, `vaultwarden`, `immich`,
  `g3`, `s3-orchestrator`, `flight-fetcher`, `sonarr`, `radarr`, `lidarr`,
  `readarr`, `prowlarr`

## notable configuration

- `priority = 80` so Patroni preempts lower-priority workloads on the DB nodes
- `pg_hba.conf` allows `hostssl replication` from `0.0.0.0/0` with
  scram-sha-256 -- replication is gated by TLS + Vault-issued creds, not IP
- `init` task pre-creates `/opt/nomad/data/patroni-${idx}` via a busybox
  prestart step
- rolling restarts cause a brief primary failover; deploy dependent apps
  AFTER Patroni stabilizes
