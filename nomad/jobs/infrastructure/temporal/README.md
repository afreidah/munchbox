# Temporal

Workflow orchestration engine that powers the automated backup and
vulnerability scanning systems. The server exposes a gRPC API for workflow
submissions and uses Patroni PostgreSQL as its persistence backend. The UI
provides a web interface for monitoring workflow executions and debugging
failures.

Two separate jobs deploy the server and UI independently, allowing the UI
to be updated without affecting running workflows.

## Notable Configuration

- The UI is unpinned from any specific node; Nomad schedules it on the
  best available node (excluding Oracle nodes) and reschedules
  automatically on failure

## Dependencies

- **Patroni** -- persistence backend (temporal and temporal_visibility databases)
- **Temporal backup/trivy workers** -- submit and execute workflows via the gRPC API
