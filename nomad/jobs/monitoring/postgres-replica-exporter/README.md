# PostgreSQL Replica Exporter

Dedicated monitoring of the Patroni replica node, separate from the primary
exporter. Running a distinct exporter for the replica ensures replication lag,
read query performance, and follower health are tracked independently, which
is critical for detecting replication drift.

## Dependencies

- **Patroni** -- the PostgreSQL replica being monitored
