# Trivy Dashboard

Custom Go web dashboard that displays vulnerability scan results from the
Temporal trivy workflow. Reads scan data from PostgreSQL and renders
color-coded severity tables with filtering. Exposes Prometheus metrics
for alerting on vulnerability counts.

## Notable Configuration

- Uses Nomad 1.11 native `secret` block for database credentials
- Connects to PostgreSQL with TLS verification using the Vault PKI CA
- Queries the Temporal server API for recent workflow execution status
- Protected by oauth2-proxy for access control
- Constrained to amd64 nodes; unpinned from any specific node so Nomad
  reschedules automatically on failure

## Dependencies

- **Patroni** -- PostgreSQL database (trivy database, written by backup worker)
- **Temporal** -- workflow status queries
- **Vault** -- database credentials and PKI CA certificate
