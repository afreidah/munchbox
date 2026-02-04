# Loki

Centralized log aggregation with label-based indexing. Receives logs from
Promtail agents running across all cluster nodes and stores them with 5-day
retention on local storage. Queryable through Grafana using LogQL. Co-located
with Tempo on the same node to keep the observability stack together.

## Dependencies

- **Promtail** -- log collection agents feeding Loki
- **Grafana** -- primary query and visualization interface
