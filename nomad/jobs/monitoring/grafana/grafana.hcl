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
user         = "root"
vault        = true

# --- Traefik routing ---
traefik      = true
traefik_host = "grafana.munchbox.cc"

# --- Health check ---
health_path = "/api/health"

# --- Environment ---
env = {
  GF_SERVER_SERVE_FROM_SUB_PATH = "false"
  GF_SERVER_ROOT_URL            = "https://grafana.munchbox.cc/"
}

# --- Host volume mounts ---
volumes = [
  "/mnt/gdrive/munchbox-data/grafana:/var/lib/grafana"
]

# --- Configuration templates ---
templates = [
  { src = "grafana.env.tpl", dest = "/secrets/grafana.env", env = true, vault = true }
]

# --- Service tags ---
tags = [
  "monitoring",
  "grafana",
  "traefik.http.routers.grafana.middlewares=authentik@file"
]
