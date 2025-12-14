# -------------------------------------------------------------------------------
# Nextcloud Exporter — Cloud Storage Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports Nextcloud serverinfo metrics for Prometheus scraping. Connects to
# Nextcloud via internal port. Auth token retrieved from Vault at runtime.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "nextcloud-exporter"
image       = "xperimental/nextcloud-exporter:0.7.0"
port        = 9205
static_port = 9205
size        = "tiny"
vault       = true

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path    = "/metrics"
health_timeout = "35s"
health_interval = "60s"

# --- Environment (static) ---
# Note: Using direct IP since container doesn't have Consul DNS
# Nextcloud runs on goren (192.168.68.60) with static port 18081
env = {
  TZ                            = "America/Los_Angeles"
  NEXTCLOUD_SERVER              = "http://192.168.68.60:18081"
  NEXTCLOUD_TIMEOUT             = "30s"
  NEXTCLOUD_TLS_SKIP_VERIFY     = "true"
}

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "nextcloud.env", dest = "secrets/nextcloud.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "nextcloud-exporter", "metrics", "cloud"]
