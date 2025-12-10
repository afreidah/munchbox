# -------------------------------------------------------------------------------
# Sonarr — TV Show Management
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "sonarr"
type         = "service"
image        = "linuxserver/sonarr:latest"
port         = 8989
static_port  = 8989
host_network = true
node         = "nomad-client-01"
size         = "medium"
cpu          = 1500

# --- Storage ---
storage      = "local"
storage_path = "/config"
volumes = [
  "/mnt/gdrive/media/TV:/tv",
  "/mnt/gdrive/nomad_deluge_downloads:/downloads",
  "/mnt/gdrive/nomad_deluge_completed:/completed"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "sonarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "sonarr",
  "media",
  "arr",
  "traefik.http.routers.sonarr.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.sonarr-http.rule=Host(`sonarr.munchbox.cc`)",
  "traefik.http.routers.sonarr-http.entrypoints=web",
  "traefik.http.routers.sonarr-http.middlewares=cf-tunnel-https@file,authentik@file"
]
