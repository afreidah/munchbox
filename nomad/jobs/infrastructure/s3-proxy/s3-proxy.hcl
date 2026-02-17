# -------------------------------------------------------------------------------
# S3 Proxy -- Unified S3 Endpoint with Quota Management
#
# Project: Munchbox / Author: Alex Freidah
#
# S3-compatible proxy that routes objects to OCI Object Storage backends with
# per-backend quota tracking. Stores metadata in PostgreSQL on the shared
# Patroni cluster. Exposes Prometheus metrics and OpenTelemetry traces.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "s3-proxy"
image = "registry.munchbox.cc/s3-proxy:latest"
port  = 9000
size  = "small"
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
tags = ["infrastructure", "s3-proxy", "storage"]
