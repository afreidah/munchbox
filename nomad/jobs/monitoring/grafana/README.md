# Grafana

Visualization layer for the monitoring stack, rendering dashboards from
Prometheus metrics, Loki logs, and Tempo traces. Ships with provisioned
datasources and dashboards covering infrastructure services, Nomad cluster
health, certificate management, and community dashboards for Node Exporter,
Traefik, Vault, Proxmox, and Blackbox Exporter.

Uses PostgreSQL on the shared Patroni cluster for state persistence, allowing
Nomad to schedule Grafana on any node. All dashboards and datasources are
provisioned from version-controlled files so the database only holds session
and user state.

## Dependencies

- **Patroni (PostgreSQL)** -- database backend for Grafana state
- **Prometheus** -- primary metrics datasource
- **Loki** -- log aggregation datasource
- **Tempo** -- distributed tracing datasource
- **Vault** -- admin credentials and database credentials via `secret/data/grafana`
