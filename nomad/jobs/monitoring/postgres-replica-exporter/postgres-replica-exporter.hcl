# -------------------------------------------------------------------------------
# PostgreSQL Replica Exporter — Database Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports PostgreSQL metrics for Prometheus scraping. Connects to postgres-replica
# via Consul DNS for monitoring the Patroni replica node.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "postgres-replica-exporter"
image       = "quay.io/prometheuscommunity/postgres-exporter:v0.18.1"
port        = 9188
static_port = 9188
size        = "tiny"
vault       = true
args        = ["--web.listen-address=:9188"]

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
  { src = "data_source.env", dest = "secrets/postgres.env", env = true },
  { src = "ca.crt", dest = "secrets/ca.crt", env = false }
]

# --- Volume mounts for TLS ---
volumes = ["secrets/ca.crt:/etc/ssl/postgres/ca.crt:ro"]

# --- Service tags ---
tags = ["monitoring", "postgres-exporter", "postgres-replica-exporter", "metrics", "database", "replica"]
