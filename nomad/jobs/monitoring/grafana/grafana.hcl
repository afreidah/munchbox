# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization
#
# Project: Munchbox / Author: Alex Freidah
#
# Visualization platform for Prometheus metrics and Loki logs. Uses persistent
# storage on Google Drive mount for dashboard and configuration retention across
# restarts. Integrates with Vault for admin credentials.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "grafana"
image        = "grafana/grafana:12.3.0"
port         = 3000
static_port  = 3000
host_network = true
size         = "medium"
vault        = true

# --- Traefik routing ---
traefik      = true
traefik_host = "grafana.munchbox.cc"

# --- Health check ---
health_path = "/api/health"

# --- Environment ---
env = {
  GF_SERVER_SERVE_FROM_SUB_PATH              = "false"
  GF_SERVER_ROOT_URL                         = "https://grafana.munchbox.cc/"
  # Dark theme by default (closest to Catppuccin Mocha without custom CSS)
  GF_USERS_DEFAULT_THEME                     = "dark"
  # OpenTelemetry tracing to Tempo
  GF_TRACING_OPENTELEMETRY_OTLP_ADDRESS      = "tempo.service.consul:4317"
  GF_TRACING_OPENTELEMETRY_OTLP_PROPAGATION  = "w3c"
}

# --- Host volume mounts ---
volumes = [
  "/mnt/gdrive/munchbox-data/grafana:/var/lib/grafana"
]

# --- Configuration templates ---
templates = [
  { src = "grafana.env.tpl", dest = "/secrets/grafana.env", env = true, vault = true },
  { src = "datasources.yml", dest = "/etc/grafana/provisioning/datasources/datasources.yml", vault = false },
  { src = "dashboards.yml", dest = "/etc/grafana/provisioning/dashboards/dashboards.yml", vault = false },
  { src = "dashboards/infrastructure-services.json", dest = "/etc/grafana/provisioning/dashboards/json/infrastructure-services.json", vault = false },
  { src = "dashboards/nomad-cluster-overview.json", dest = "/etc/grafana/provisioning/dashboards/json/nomad-cluster-overview.json", vault = false }
]

# --- Service tags ---
tags = [
  "monitoring",
  "grafana",
  "traefik.http.routers.grafana.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.grafana-http.rule=Host(`grafana.munchbox.cc`)",
  "traefik.http.routers.grafana-http.entrypoints=web",
  "traefik.http.routers.grafana-http.middlewares=cf-tunnel-https@file,authentik@file"
]
