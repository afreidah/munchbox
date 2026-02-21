# -------------------------------------------------------------------------------
# S3 Orchestrator -- Unified S3 Endpoint with Quota Management
#
# Project: Munchbox / Author: Alex Freidah
#
# S3-compatible orchestrator that routes objects to OCI Object Storage backends
# with per-backend quota tracking. Stores metadata in PostgreSQL on the shared
# Patroni cluster. Exposes Prometheus metrics and OpenTelemetry traces.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "s3-orchestrator"
image = "registry.munchbox.cc/s3-orchestrator:latest"
port         = 9000
host_network = true
size         = "medium"
vault = true

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/health"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
args = ["-config", "/secrets/config.yaml"]

# --- Configuration templates ---
templates = [
  { src = "config.yaml.tpl", dest = "/secrets/config.yaml", vault = true }
]

# --- Service tags ---
tags = ["infrastructure", "s3-orchestrator", "storage"]
