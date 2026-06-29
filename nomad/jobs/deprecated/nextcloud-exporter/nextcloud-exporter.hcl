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
image       = "xperimental/nextcloud-exporter:0.9.0"
port        = 9205
static_port = 9205
size        = "tiny"
vault       = true

# --- Placement ---
node = "any"

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path     = "/metrics"
health_timeout  = "35s"
health_interval = "60s"

# --- Environment (static) ---
# Use Consul DNS to dynamically resolve Nextcloud
env = {
  TZ                        = "America/Los_Angeles"
  NEXTCLOUD_SERVER          = "https://nextcloud.munchbox.cc"
  NEXTCLOUD_TIMEOUT         = "30s"
  NEXTCLOUD_TLS_SKIP_VERIFY = "true"
}

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "nextcloud.env", dest = "secrets/nextcloud.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "nextcloud-exporter", "metrics", "cloud", "scrape-interval=60s", "scrape-timeout=30s"]
