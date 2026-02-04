# Prometheus

Central metrics collection and alerting engine for the cluster. Uses Consul
service discovery to dynamically find all scrape targets across Nomad, Consul,
Vault, and exporter services, eliminating manual target configuration. Alert
rules evaluate infrastructure health conditions and forward firing alerts to
Alertmanager for notification routing. Receives remote write data from Tempo
for trace-derived RED metrics.

## Dependencies

- **Alertmanager** -- receives and routes alerts
- **All exporter services** -- scrape targets providing metrics
