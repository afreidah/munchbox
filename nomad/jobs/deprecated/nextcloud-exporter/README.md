# Nextcloud Exporter

Collects serverinfo metrics from the Nextcloud instance and exposes them for
Prometheus scraping. Provides visibility into active users, storage
consumption, and application health.

## Notable Configuration

- Unpinned from any specific node; Nomad schedules it on the best
  available node and reschedules automatically on failure

## Dependencies

- **Nextcloud** -- the cloud storage instance being monitored
