# PostgreSQL Exporter

Collects metrics from the Patroni PostgreSQL primary and exposes them for
Prometheus scraping. Connects over TLS via Consul DNS with credentials from
Vault, providing visibility into query performance, connection pools, and
replication status.

## Dependencies

- **Patroni** -- the PostgreSQL cluster being monitored
