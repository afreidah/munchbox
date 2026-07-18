# -------------------------------------------------------------------------------
# Docker Registry — Container Image Storage with UI
#
# Project: Munchbox / Author: Alex Freidah
#
# Docker Registry v2 for storing and distributing container images within the
# cluster. Includes web UI for browsing repositories and managing images.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "registry"
type         = "service"
image        = "registry:3.1.1"
port         = 5000
static_port  = 5000
host_network = true
node         = "stabler"
size         = "large"

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/mnt/gdrive/munchbox-data/registry:/var/lib/registry"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "registry.munchbox.cc"

# --- Health check ---
health_path = "/v2/"

# --- Environment (OTEL tracing to Tempo) ---
env = {
  OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4318"
  OTEL_EXPORTER_OTLP_INSECURE = "true"
}

# --- Container arguments ---
args = ["serve", "/local/config.yml"]

# --- Configuration templates ---
templates = [
  { src = "registry-config.yml", dest = "/local/config.yml", vault = false }
]

# --- Service tags ---
tags = [
  "docker",
  "registry",
  "infrastructure",
]

# --- Termination ---
kill_timeout = "30s"
