# -------------------------------------------------------------------------------
# Prowlarr — Indexer Management
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "prowlarr"
type         = "service"
image        = "linuxserver/prowlarr:latest"
port         = 9696
static_port  = 9696
host_network = true
node         = "nomad-client-03"
size         = "medium"
memory       = 300
cpu          = 1000

# --- Storage ---
storage      = "local"
storage_path = "/config"

# --- Traefik routing ---
traefik      = true
traefik_host = "prowlarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "prowlarr",
  "media",
  "arr",
  "traefik.http.routers.prowlarr.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.prowlarr-http.rule=Host(`prowlarr.munchbox.cc`)",
  "traefik.http.routers.prowlarr-http.entrypoints=web",
  "traefik.http.routers.prowlarr-http.middlewares=cf-tunnel-https@file,authentik@file"
]
