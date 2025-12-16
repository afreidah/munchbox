# -------------------------------------------------------------------------------
# PostgreSQL Replica Exporter — Replica Database Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports PostgreSQL replica metrics for Prometheus scraping. Connects to
# postgres-replica via Consul DNS on port 5433. Used for monitoring replication
# lag and replica health.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "postgres-replica-exporter"
image       = "quay.io/prometheuscommunity/postgres-exporter:v0.18.1"
port        = 9188
static_port = 9188
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

# --- Override default port to avoid conflict with primary exporter ---
args = ["--web.listen-address=:9188"]

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "data_source.env", dest = "secrets/postgres.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "postgres-exporter", "metrics", "database", "replica"]
