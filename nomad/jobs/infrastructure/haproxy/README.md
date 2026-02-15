# HAProxy

TCP proxy in front of Patroni (PostgreSQL) and Redis Sentinel that provides
automatic connection failover. On a database failover event, HAProxy detects
the role change via health checks and immediately terminates stale client
connections, forcing applications to reconnect to the new primary without
manual intervention.

## Architecture

Two instances run on goren and stabler (the same nodes as Patroni and Redis)
using host networking. Each HAProxy instance independently health-checks all
database backends and routes traffic to whichever is currently primary. Consul
load-balances application traffic across both HAProxy instances via the
`haproxy-postgres` and `haproxy-redis` service names.

Backends are discovered dynamically via HAProxy's built-in DNS resolver
querying Consul DNS on port 8600. This avoids Nomad template `{{ range
service }}` which is limited by per-task Consul SI token scoping.

## Components

| Task | Role | Lifecycle |
|------|------|-----------|
| haproxy | TCP proxy with health-check routing for PostgreSQL and Redis | main |

## Data Flow

```
App -> haproxy-postgres.service.consul:5433 -> HAProxy -> Patroni primary (5432)
App -> haproxy-redis.service.consul:6380   -> HAProxy -> Redis master (6379)
```

**PostgreSQL routing**: HAProxy issues `GET /primary` against each Patroni REST
API (port 8008). Only the current leader returns HTTP 200; replicas return 503.
Traffic is forwarded to the backend that passes this check.

**Redis routing**: HAProxy authenticates to each Redis instance and runs
`INFO replication`, checking for `role:master`. Only the current master receives
traffic.

**Failover behavior**: `on-marked-down shutdown-sessions` immediately closes all
TCP connections to a backend when it fails health checks (e.g. after a Patroni
switchover or Redis Sentinel failover). Applications receive a connection reset
and reconnect through HAProxy to the new primary.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| `haproxy-postgres` | 5433 | PostgreSQL proxy (routes to Patroni primary) |
| `haproxy-redis` | 6380 | Redis proxy (routes to Redis master) |
| `haproxy-stats` | 8405 | Stats dashboard at `/stats` |
| `haproxy-metrics` | 8405 | Prometheus metrics at `/metrics` |

## Failure Modes

- **Patroni failover**: HAProxy detects the new primary within ~9s (3 checks at
  3s intervals). Connections to the demoted primary are killed immediately.
  Applications reconnect through HAProxy to the new primary automatically.
- **Redis Sentinel failover**: Same detection and teardown behavior via the
  `INFO replication` health check.
- **HAProxy instance crash**: Consul removes the failed instance from DNS. Apps
  reconnect to the surviving HAProxy instance on the other node.
- **Both HAProxy instances down**: Applications cannot reach databases via the
  proxy service names. Direct `postgres-primary.service.consul:5432` and
  `redis-primary.service.consul:6379` still work as a fallback.

## Dependencies

**Requires:**
- Patroni (PostgreSQL backends on port 5432, REST API on port 8008)
- Redis Sentinel (Redis backends on port 6379)
- Consul DNS (port 8600 on localhost for backend discovery)
- Vault (Redis password at `secret/data/redis-shared`)

**Required by:**
- Nextcloud (PostgreSQL + Redis)
- Forgejo (PostgreSQL + Redis)
- Immich (PostgreSQL + Redis)
- Umami (PostgreSQL)
- Trivy Dashboard (PostgreSQL)
- Trivy Server (Redis)
- Temporal Server (PostgreSQL)
- Temporal Backup Worker (PostgreSQL)

## Notable Configuration

- Priority 75 ensures HAProxy starts after databases (priority 80) but before
  application services (priority 50)
- Uses a raw `.nomad.hcl` file instead of munchbox-service pack because the job
  registers 4 Consul services from a single task group
- `server-template` with Consul DNS resolver replaces Nomad `{{ range service }}`
  to avoid Consul SI token scope limitations in Nomad v1.11.1
- Long client/server timeouts (30m) accommodate long-running database queries
  and idle connection pools
- Patroni TLS certificates include `haproxy-postgres.service.consul` in their
  SANs so TLS verification succeeds through the proxy

## Operational Notes

- **Stats dashboard**: `http://goren:8405/stats` or `http://stabler:8405/stats`
  shows backend health, active connections, and failover history
- **Verify routing**: Check the stats page to confirm which backend is marked UP
  (primary) vs DOWN (replica) for each proxy
- **Prometheus metrics**: Scraped from the `haproxy-metrics` Consul service at
  `/metrics` on port 8405
