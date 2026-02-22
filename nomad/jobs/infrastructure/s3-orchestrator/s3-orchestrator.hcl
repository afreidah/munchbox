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
image = "registry.munchbox.cc/s3-orchestrator:v0.5.0"
port         = 9000
host_network = true
size         = "medium"
vault = true

# --- Traefik routing ---
traefik        = true
traefik_host   = "s3.munchbox.cc"
traefik_public = true

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
tags = [
  "infrastructure",
  "s3-orchestrator",
  "storage",
  "traefik.http.routers.s3-orchestrator.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.s3-orchestrator-http.rule=Host(`s3.munchbox.cc`)",
  "traefik.http.routers.s3-orchestrator-http.entrypoints=web",
  "traefik.http.routers.s3-orchestrator-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
