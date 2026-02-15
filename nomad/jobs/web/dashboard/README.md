# Dashboard

Hugo-based static dashboard served through NGINX. Provides a centralized
starting page with links to operational web interfaces across the cluster
(Nomad, Consul, Grafana, Proxmox, etc.). Configuration lives in
`src/dashboard/data/config.yaml`.

## Notable Configuration

- Unpinned from any specific node; Nomad schedules it on the best
  available node and reschedules automatically on failure
