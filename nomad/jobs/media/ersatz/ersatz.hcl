# -------------------------------------------------------------------------------
# ErsatzTV — Virtual TV Channel Engine with Emby Integration
#
# Project: Munchbox / Author: Alex Freidah
#
# ErsatzTV creates virtual TV channels from your media library with scheduling,
# commercials, and live streaming capabilities. Integrates with Emby for content.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "ersatztv"
type  = "service"
image = "jasongdove/ersatztv:latest"
port  = 8409
static_port = 8409
host_network = true
node = "nomad-client-02"
cpu    = 500   # Reduced from 2000 - actual usage ~1%
memory = 800   # Keep memory - actual usage 658MB

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/ersatztv/config:/config",
  "/opt/nomad/data/ersatztv/transcode:/transcode",
  "/mnt/gdrive/media/Movies:/media/Movies:ro",
  "/mnt/gdrive/media/TV:/media/TV:ro"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "ersatz.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment variables ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "media",
  "ersatztv",
  "streaming",
  "traefik.http.routers.ersatztv.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.ersatztv-http.rule=Host(`ersatz.munchbox.cc`)",
  "traefik.http.routers.ersatztv-http.entrypoints=web",
  "traefik.http.routers.ersatztv-http.middlewares=cf-tunnel-https@file,authentik@file"
]

# --- Termination ---
kill_timeout = "30s"
