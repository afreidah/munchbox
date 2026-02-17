# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization
#
# Project: Munchbox / Author: Alex Freidah
#
# Visualization platform for Prometheus metrics and Loki logs. Uses PostgreSQL
# on the shared Patroni cluster for state persistence. All dashboards and
# datasources are provisioned from version-controlled files.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "grafana"
image        = "grafana/grafana:12.3.0"
port         = 3030
host_network = false
size         = "medium"
vault        = true

# --- Placement ---
node = "any"

# --- Traefik routing ---
traefik      = true
traefik_host = "grafana.munchbox.cc"

# --- Health check ---
health_path = "/api/health"

# --- Environment ---
env = {
  GF_SERVER_HTTP_PORT                        = "3030"
  GF_SERVER_SERVE_FROM_SUB_PATH              = "false"
  GF_SERVER_ROOT_URL                         = "https://grafana.munchbox.cc/"
  # Dark theme by default (closest to Catppuccin Mocha without custom CSS)
  GF_USERS_DEFAULT_THEME                     = "dark"
  # OpenTelemetry tracing to Tempo
  GF_TRACING_OPENTELEMETRY_OTLP_ADDRESS      = "tempo.service.consul:4317"
  GF_TRACING_OPENTELEMETRY_OTLP_PROPAGATION  = "w3c"
}

# --- Storage ---
storage = "ephemeral"

# --- Configuration templates ---
templates = [
  { src = "grafana.env.tpl", dest = "/secrets/grafana.env", env = true, vault = true },
  { src = "datasources.yml", dest = "/etc/grafana/provisioning/datasources/datasources.yml", vault = false },
  { src = "dashboards.yml", dest = "/etc/grafana/provisioning/dashboards/dashboards.yml", vault = false },
  # Custom dashboards
  { src = "dashboards/infrastructure-services.json", dest = "/etc/grafana/provisioning/dashboards/json/infrastructure-services.json", vault = false },
  { src = "dashboards/nomad-cluster-overview.json", dest = "/etc/grafana/provisioning/dashboards/json/nomad-cluster-overview.json", vault = false },
  { src = "dashboards/nomad-workloads.json", dest = "/etc/grafana/provisioning/dashboards/json/nomad-workloads.json", vault = false },
  { src = "dashboards/certificate-management.json", dest = "/etc/grafana/provisioning/dashboards/json/certificate-management.json", vault = false },
  { src = "dashboards/s3-proxy.json", dest = "/etc/grafana/provisioning/dashboards/json/s3-proxy.json", vault = false },
  # Community dashboards
  { src = "dashboards/hashicorp-nomad.json", dest = "/etc/grafana/provisioning/dashboards/json/hashicorp-nomad.json", vault = false },
  { src = "dashboards/hashicorp-vault.json", dest = "/etc/grafana/provisioning/dashboards/json/hashicorp-vault.json", vault = false },
  { src = "dashboards/node-exporter-full.json", dest = "/etc/grafana/provisioning/dashboards/json/node-exporter-full.json", vault = false },
  { src = "dashboards/nomad-clients.json", dest = "/etc/grafana/provisioning/dashboards/json/nomad-clients.json", vault = false },
  { src = "dashboards/prometheus-blackbox-exporter.json", dest = "/etc/grafana/provisioning/dashboards/json/prometheus-blackbox-exporter.json", vault = false },
  { src = "dashboards/proxmox-via-prometheus.json", dest = "/etc/grafana/provisioning/dashboards/json/proxmox-via-prometheus.json", vault = false },
  { src = "dashboards/traefik-official-standalone-dashboard.json", dest = "/etc/grafana/provisioning/dashboards/json/traefik-official-standalone-dashboard.json", vault = false },
]

# --- Service tags ---
tags = [
  "monitoring",
  "grafana",
  "traefik.http.routers.grafana.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.grafana-http.rule=Host(`grafana.munchbox.cc`)",
  "traefik.http.routers.grafana-http.entrypoints=web",
  "traefik.http.routers.grafana-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file"
]
