# -------------------------------------------------------------------------------
# PostgreSQL Exporter — Database Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports PostgreSQL metrics for Prometheus scraping. Connects to postgres-shared
# via Consul DNS. Credentials retrieved from Vault at runtime.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "postgres-exporter"
image       = "quay.io/prometheuscommunity/postgres-exporter:v0.18.1"
port        = 9187
static_port = 9187
size        = "tiny"
vault       = true

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/metrics"

# --- Environment (static) ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "data_source.env", dest = "secrets/postgres.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "postgres-exporter", "metrics", "database"]
