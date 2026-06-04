# alloy

Grafana Alloy as the cluster's unified telemetry agent, replacing
promtail. Ships systemd journal entries and Nomad allocation logs to
Loki, and also runs the node_exporter Unix collector and remote-writes
host metrics to Prometheus. Runs on every node.

## Image

`grafana/alloy:v1.16.2`

## Hostname / exposure

- No traefik (`traefik.enable=false`)
- Internal HTTP on static port 12345 (`/-/ready` healthcheck)
- Discovered by Prometheus and Grafana via Consul

## Placement

- `type = system`, `node_pool = all` -- one alloc per Nomad client

## Dependencies

- Loki at `loki.service.consul:3100` (log push)
- Prometheus at `prometheus.service.consul:9090/api/v1/write`
  (metric remote write)
- Host bind mounts: `/var/log/journal`, `/run/log/journal`,
  `/etc/machine-id`, `/var/lib/nomad/alloc`, and `/:/host:ro,rslave`
  for the node-exporter rootfs view
- On `meta.cloud=oracle` nodes, also scrapes the oracle-watchdog
  monitor at `localhost:9104`

## Notable configuration

- Host network + `pid_mode = host` so the Unix exporter sees the real
  process table
- JSON pipeline pulls `level` to a label and promotes `trace_id` /
  `span_id` to structured metadata for trace-to-log correlation
- Node-metrics scrape preserves `job_name = "node-exporter"` so
  existing Prometheus rules and dashboards keep matching
- `instance` label rewritten to `node.unique.name` so metrics line up
  with the Nomad node name, not the container hostname
