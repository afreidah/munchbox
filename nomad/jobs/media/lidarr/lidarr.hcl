# -------------------------------------------------------------------------------
# Lidarr — Music Management
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "lidarr"
type         = "service"
image        = "linuxserver/lidarr:latest"
port         = 8686
static_port  = 8686
host_network = true
node         = "nomad-client-02"
size         = "medium"

# --- Health check (use /ping to avoid auth failures in logs) ---
health_path  = "/ping"

# --- Storage ---
storage      = "local"
storage_path = "/config"
volumes = [
  "/mnt/gdrive/media/Music:/music",
  "/mnt/gdrive/nomad_deluge_downloads:/downloads",
  "/mnt/gdrive/nomad_deluge_completed:/completed"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "lidarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "lidarr",
  "media",
  "arr",
  "music",
  "traefik.http.routers.lidarr.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.lidarr-http.rule=Host(`lidarr.munchbox.cc`)",
  "traefik.http.routers.lidarr-http.entrypoints=web",
  "traefik.http.routers.lidarr-http.middlewares=cf-tunnel-https@file,authentik@file"
]
