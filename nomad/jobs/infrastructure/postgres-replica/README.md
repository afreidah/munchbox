# PostgreSQL Replica

Hot standby streaming replica of the postgres-shared primary. Provides
read-only query capacity and data redundancy on a separate physical node.

## Architecture

Three tasks run in sequence. The init-storage prestart ensures directory
permissions. The basebackup prestart runs `pg_basebackup` from the primary
if the data directory is empty (first-time setup only). The main postgres
task starts in standby mode, continuously applying WAL from the primary
via the `replica_slot` replication slot.

## Components

| Task         | Role                               | Lifecycle |
|--------------|------------------------------------|-----------|
| init-storage | Create data directory, fix perms   | prestart  |
| basebackup   | Initial pg_basebackup from primary | prestart  |
| postgres     | Streaming replica (hot standby)    | main      |

## Notable Configuration

- Pinned to nomad-client-02 (primary is on nomad-client-03) for physical
  separation
- Listens on port 5433 to avoid conflicts if both jobs ever land on the
  same node
- Basebackup task is idempotent: skips if `PG_VERSION` file already exists
- Uses a named replication slot (`replica_slot`) to prevent WAL cleanup
  before the replica has consumed it
- `hot_standby_feedback = on` prevents the primary from vacuuming rows
  the replica still needs for long queries

## Dependencies

- **postgres-shared** -- replication source (primary)
- **Vault** -- replication user credentials
