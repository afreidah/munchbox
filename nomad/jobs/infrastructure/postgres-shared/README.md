# PostgreSQL Shared (Primary)

Multi-tenant PostgreSQL 16 instance serving as the primary database for
most cluster services. Runs alongside the Patroni HA cluster as a
separate, simpler deployment for workloads that do not require automatic
failover.

## Architecture

A prestart init-storage task ensures the data directory exists with correct
ownership. The main postgres task starts with streaming replication enabled
(`wal_level=replica`) so the postgres-replica job can follow along as a
hot standby. Init SQL scripts templated from Vault create each tenant's
database and user on first boot.

## Data Flow

Write traffic from all tenant services reaches this primary on port 5432
via `postgres-primary.service.consul`. WAL segments stream to the replica
on nomad-client-02 for read scaling and disaster recovery. The backup
worker dumps all databases nightly from this primary.

## Tenants

Databases initialized on first boot (credentials from Vault):

- **nextcloud** -- Nextcloud file metadata and sharing
- **temporal** / **temporal_visibility** -- Temporal workflow engine
- **trivy** -- vulnerability scan results (includes schema DDL)
- **woodpecker** -- legacy CI database
- **forgejo** -- Git repository metadata
- **umami** -- web analytics

## Notable Configuration

- Pinned to nomad-client-03 with local SSD storage for performance
- Priority 75 ensures the database starts before dependent services
- WAL keep size of 256MB accommodates replica catch-up after brief outages
- Init scripts use `change_mode = "noop"` to prevent restarts when Vault
  secrets rotate (scripts only run on first boot anyway)

## Dependencies

- **Vault** -- root credentials and per-tenant database credentials
- **postgres-replica** -- streaming replication target
