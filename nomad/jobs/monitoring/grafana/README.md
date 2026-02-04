# Grafana

Visualization layer for the monitoring stack, rendering dashboards from
Prometheus metrics, Loki logs, and Tempo traces. Ships with provisioned
datasources and dashboards covering infrastructure services, Nomad cluster
health, and certificate management. Configuration and dashboard state persist
on the Google Drive NFS mount for portability across node restarts.

## Dependencies

- **Prometheus** -- primary metrics datasource
- **Loki** -- log aggregation datasource
- **Tempo** -- distributed tracing datasource
