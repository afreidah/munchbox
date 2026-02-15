# Redis Sentinel

High-availability Redis cluster with automatic failover managed by Sentinel.
Runs 2 Redis instances (master + replica) and 3 Sentinels for quorum.
Provides the caching and session storage layer for services that need Redis.

## Architecture

Two task groups operate together. The `redis` group (count=2) runs on
distinct bare-metal hosts, each containing a Redis server, a co-located
Sentinel, and a metrics exporter. The `sentinel-quorum` group (count=1) runs
a standalone Sentinel on a third node to satisfy the quorum requirement of 3.

Host networking is used for the same reason as Patroni: Redis clients across
the cluster connect via Consul DNS, and addresses must be routable from all
network namespaces including bridge-mode containers.

Allocation index 0 bootstraps as master. Other allocations discover the
master via the `redis-primary` Consul service and configure themselves as
replicas. Sentinel monitors the master and promotes a replica automatically
if the master becomes unreachable.

## Components

**redis group (x2):**

| Task | Role | Lifecycle |
|------|------|-----------|
| init-storage | Creates data directories, cleans stale sentinel config | prestart |
| redis | Redis server (master or replica depending on Sentinel state) | main |
| sentinel | Sentinel instance for failover voting | main (concurrent) |
| redis-exporter | Prometheus metrics sidecar | poststart sidecar |

**sentinel-quorum group (x1):**

| Task | Role | Lifecycle |
|------|------|-----------|
| sentinel | Standalone Sentinel for quorum (no local Redis) | main |

The standalone sentinel waits for a valid master IP in its config template
before starting, avoiding a race condition where Consul service resolution
has not yet completed.

## Data Flow

Application traffic routes through HAProxy at
`haproxy-redis.service.consul:6380`, which checks `INFO replication` on each
Redis instance and forwards to the current master on port 6379. On failover,
HAProxy kills stale connections and re-routes to the new master automatically.

Replication is asynchronous from master to replica. Persistence uses both
RDB snapshots (every 60s if at least 1 key changed) and AOF with everysec
fsync.

Sentinel consensus requires 2 of 3 Sentinels to agree a master is down
(`quorum 2`) before triggering failover. Failover timeout is 60s with a
down-after-milliseconds of 5s.

## Failure Modes

- **Master crash**: Sentinel detects failure within 5s, initiates failover
  after quorum agreement. The replica is promoted, and Consul service routing
  updates automatically via the script-based health checks that inspect
  `INFO replication` output.
- **Replica crash**: No impact on write availability. Read-only service
  becomes unavailable until replica recovers.
- **Split brain prevention**: Quorum of 3 Sentinels prevents split-brain.
  `parallel-syncs 1` ensures only one replica re-syncs at a time during
  failover.
- **Stale sentinel config**: The init-storage task removes sentinel.conf on
  every start to prevent stale master references from a previous allocation.

## Dependencies

**Requires:**
- Vault (Redis password at `secret/data/redis-shared`)

**Required by:**
- HAProxy (proxies connections from apps to the current master)
- Nextcloud, Forgejo, Immich, Trivy Server (via HAProxy)

## Notable Configuration

- Priority 80 ensures Redis starts before application services
- Constrained to bare-metal nodes only (excludes Oracle Cloud nodes) to
  avoid WireGuard tunnel latency on a latency-sensitive data store
- Memory capped at 512MB with noeviction policy -- Redis returns errors
  rather than silently dropping keys when full
- The `redis` generic service (healthy on all instances via TCP check)
  exists solely for bootstrap: the quorum sentinel uses it to discover any
  Redis instance and let Sentinel resolve the actual master
