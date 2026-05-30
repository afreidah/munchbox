# Redis Exporter

Collects metrics from the Redis Sentinel cluster and exposes them for
Prometheus scraping. Connects to the primary Redis instance via Consul DNS
and retrieves authentication credentials from Vault at runtime.

## Dependencies

- **Redis Sentinel** -- the Redis cluster being monitored
