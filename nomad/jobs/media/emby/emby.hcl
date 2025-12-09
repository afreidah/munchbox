# -------------------------------------------------------------------------------
# Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
# Project: Munchbox / Author: Alex Freidah
#
# Emby media server with GPU transcoding and library management
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "emby"
type  = "service"
image = "linuxserver/emby:latest"
port  = 8096
static_port = 8096
host_network = true
node = "nomad-client-01"
cpu    = 900
memory = 3276

# --- Additional ports ---
extra_ports = [
  { name = "https", port = 8920, static = true }
]

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/emby/config:/config",
  "/opt/nomad/data/emby/cache:/cache",
  "/opt/nomad/data/emby/transcode:/transcode",
  "/mnt/gdrive/media/Movies:/media/Movies:ro",
  "/mnt/gdrive/media/TV:/media/TV:ro",
  "/mnt/gdrive/media/Music:/media/Music:ro",
  "/mnt/gdrive/media/Books:/media/Books:ro",
  "/mnt/gdrive/media/ISOs:/media/ISOs:ro",
  "/mnt/gdrive/media/Software:/media/Software:ro",
  "/mnt/gdrive/media/hacker-magazines:/media/hacker-magazines:ro",
  "/mnt/gdrive/media/random:/media/random:ro",
  "/mnt/gdrive/media/taxes:/media/taxes:ro"
]

# --- Device access for GPU transcoding ---
devices = [
  { host = "/dev/dri", container = "/dev/dri" }
]

# --- Traefik routing ---
traefik      = true
traefik_host = "emby.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "media",
  "emby",
  "streaming"
]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
