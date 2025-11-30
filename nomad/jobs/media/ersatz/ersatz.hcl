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
size = "medium"

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/ersatztv/config:/config",
  "/opt/nomad/data/ersatztv/transcode:/transcode",
  "/mnt/gdrive/media/Movies:/media/Movies:ro",
  "/mnt/gdrive/media/TV:/media/TV:ro"
]

# --- Traefik routing ---
traefik      = false

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
  "streaming"
]

# --- Termination ---
kill_timeout = "30s"
