# Promtail

System job running on every node to collect logs from systemd journal and
Nomad allocation log files. Forwards logs to Loki for centralized aggregation
and querying via Grafana. Uses host networking and journal mounts for direct
access to system and container logs.

## Dependencies

- **Loki** -- receives and stores the collected logs
