# -------------------------------------------------------------------------------
# Loki — Centralized Log Aggregation
#
# Project: Munchbox / Author: Alex Freidah
#
# Loki provides horizontally-scalable log aggregation with label-based indexing.
# Receives logs from Promtail agents running across all cluster nodes and stores
# them with 5-day retention on local storage.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "loki"
image        = "grafana/loki:3.5.8"
port         = 3100
static_port  = 3100
host_network = true
node         = "nomad-client-03"
size         = "medium"
user         = "root"

# --- Storage (manual pre-creation, no init task) ---
volumes = [
  "/opt/nomad/data/loki:/loki"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "loki.munchbox"

# --- Health check ---
health_path = "/ready"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
args = ["-config.file=/etc/loki/config.yaml"]

# --- Configuration templates ---
templates = [
  { src = "config.yaml", dest = "/etc/loki/config.yaml" }
]

# --- Service tags ---
tags = ["logging", "loki", "observability"]
