# Patroni

High-availability PostgreSQL 18 cluster with automatic leader election and
streaming replication. Replaces the earlier manual postgres-shared and
postgres-replica jobs with a self-healing cluster managed by Patroni. Serves
as the primary relational database for the entire Munchbox infrastructure.

## Architecture

Two instances spread across distinct hosts (goren and stabler) using host
networking. Patroni uses Consul as the distributed configuration store (DCS)
for leader election and cluster state. At any time, exactly one instance is
the primary (read-write) and the other is a streaming replica (read-only).
Consul health checks against the Patroni REST API automatically route the
`postgres-primary` and `postgres-replica` service names to the correct
instance based on current role.

Host networking is required because PostgreSQL clients throughout the cluster
-- including bridge-mode containers -- connect via Consul DNS, and the
connection address must be routable from all network namespaces.

## Components

| Task | Role | Lifecycle |
|------|------|-----------|
| init-storage | Creates pgdata directory with correct ownership (uid 999) | prestart |
| patroni | PostgreSQL server managed by Patroni | main |
| postgres-exporter | Prometheus metrics sidecar for database monitoring | poststart sidecar |

The init-storage task handles both fresh bootstraps and re-schedules to a node
where the directory may not exist yet.

## Data Flow

Application traffic routes through HAProxy at
`haproxy-postgres.service.consul:5433`, which health-checks the Patroni REST
API and forwards to the current primary on port 5432. On failover, HAProxy
kills stale connections and re-routes to the new primary automatically. Read
traffic can also target `postgres-replica.service.consul:5432` directly.

Streaming replication flows from primary to replica over the PostgreSQL
replication protocol (wal_keep_size: 256MB). All external client connections
use SCRAM-SHA-256 authentication. TLS is required for all remote connections
via Vault PKI certificates (pki_int/issue/postgres).

## Failure Modes

- **Primary crash**: Patroni detects failure via Consul session TTL (30s).
  After verifying replication lag is within `maximum_lag_on_failover` (1MB),
  the replica is promoted automatically. Consul service routing updates
  within seconds.
- **Replica crash**: No impact on write availability. The read-only service
  becomes unavailable until the replica recovers or is rescheduled.
- **Split brain prevention**: Consul quorum requirement prevents split-brain.
  Patroni uses `pg_rewind` to safely rejoin a demoted primary without full
  re-sync.
- **Both instances down**: Manual intervention required. Data persists on
  host paths (`/opt/nomad/data/patroni-{0,1}`).

## Dependencies

**Requires:**
- Consul (leader election via DCS, service registration)
- Vault (superuser/replication credentials at `secret/data/postgres-shared/*`,
  TLS certificates via `pki_int/issue/postgres`)

**Required by:**
- HAProxy (proxies connections from apps to the current primary)
- Nextcloud, Temporal Server, Forgejo, Umami, Trivy Dashboard, Immich (via HAProxy)

## Notable Configuration

- Priority 80 ensures the database starts before application services during
  cluster-wide restarts
- `register_service: false` in Patroni config because Nomad's service stanza
  handles Consul registration with role-based health checks
- Post-init script creates all application databases and users idempotently
  on initial cluster bootstrap
- Custom Patroni image (`registry.munchbox.cc/patroni:pg18`) includes the
  pgvector extension required by Immich

## Operational Notes

- **Add a new database**: Add a block to the post-init template, add the
  corresponding Vault secret, and redeploy. Existing databases are not
  affected (all CREATE statements use IF NOT EXISTS).
- **Check replication status**: `curl http://<node>:8008/cluster` on any
  Patroni instance returns cluster topology and lag.
- **Manual failover**: `curl -s http://<node>:8008/switchover -XPOST
  -d '{"leader":"<current>","candidate":"<target>"}'`
