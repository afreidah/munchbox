# -------------------------------------------------------------------------------
# Docker Registry — Container Image Storage with UI
#
# Project: Munchbox / Author: Alex Freidah
#
# Docker Registry v2 for storing and distributing container images within the
# cluster. Includes web UI for browsing repositories and managing images.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "registry"
type  = "service"
image = "registry:3"
port  = 5000
static_port = 5000
host_network = true
node = "stabler.munchbox.cc"
size = "medium"

# --- Storage ---
storage      = "ephemeral"
volumes = [
  "/mnt/gdrive/munchbox-data/registry:/var/lib/registry",
  "/mnt/gdrive/munchbox-data/certbot/traefik/munchbox.crt:/certs/munchbox.crt:ro",
  "/mnt/gdrive/munchbox-data/certbot/traefik/munchbox.key:/certs/munchbox.key:ro"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "registry.munchbox.cc"

# --- Health check (TCP since registry now uses TLS) ---
health_type = "tcp"
health_path = ""

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
  # Tell Traefik to use HTTPS when connecting to the backend
  "traefik.http.services.registry.loadbalancer.server.scheme=https",
  "traefik.http.services.registry.loadbalancer.serversTransport=insecure@file",
]

# --- Termination ---
kill_timeout = "30s"
