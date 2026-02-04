# Node Exporter

System job running on every cluster node to collect hardware and OS-level
metrics (CPU, memory, disk, network). These metrics form the foundation of
infrastructure health monitoring in Prometheus and power the Grafana
dashboards. Uses host PID namespace and root filesystem mount for accurate
system-level visibility.
