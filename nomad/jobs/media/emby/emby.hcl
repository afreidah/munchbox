# -------------------------------------------------------------------------------
# Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
# Project: Munchbox / Author: Alex Freidah
#
# Emby media server with Intel GPU transcoding for smooth playback on any device.
# Manages media library with automatic metadata and provides Live TV via ErsatzTV.
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
# Note: Setting traefik=false to disable auto-generated router, using manual tags instead
traefik      = false
traefik_host = "emby.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags (including Traefik routing) ---
tags = [
  "media",
  "emby",
  "streaming",
  # Enable Traefik
  "traefik.enable=true",
  # Service definition
  "traefik.http.services.emby.loadbalancer.server.port=8096",
  # Web UI router (with Authentik) - HTTPS
  "traefik.http.routers.emby.rule=Host(`emby.munchbox.cc`)",
  "traefik.http.routers.emby.entrypoints=websecure",
  "traefik.http.routers.emby.tls=true",
  "traefik.http.routers.emby.tls.certresolver=letsencrypt",
  "traefik.http.routers.emby.middlewares=authentik@file,emby-ratelimit@file,emby-sec@file",
  "traefik.http.routers.emby.priority=1",
  # Web UI router (with Authentik) - HTTP (for CF tunnel)
  "traefik.http.routers.emby-http.rule=Host(`emby.munchbox.cc`)",
  "traefik.http.routers.emby-http.entrypoints=web",
  "traefik.http.routers.emby-http.middlewares=cf-tunnel-https@file,authentik@file,emby-ratelimit@file,emby-sec@file",
  "traefik.http.routers.emby-http.priority=1",
  "traefik.http.routers.emby-http.service=emby",
  # API router (no Authentik) - HTTPS - for devices like Roku
  "traefik.http.routers.emby-api.rule=Host(`emby.munchbox.cc`) && (PathPrefix(`/emby`) || PathPrefix(`/mediabrowser`) || PathPrefix(`/socket`) || PathPrefix(`/Videos`) || PathPrefix(`/Items`) || PathPrefix(`/System`) || PathPrefix(`/Users/AuthenticateByName`))",
  "traefik.http.routers.emby-api.entrypoints=websecure",
  "traefik.http.routers.emby-api.tls=true",
  "traefik.http.routers.emby-api.tls.certresolver=letsencrypt",
  "traefik.http.routers.emby-api.middlewares=emby-ratelimit@file,emby-sec@file",
  "traefik.http.routers.emby-api.priority=10",
  # API router (no Authentik) - HTTP (for CF tunnel)
  "traefik.http.routers.emby-api-http.rule=Host(`emby.munchbox.cc`) && (PathPrefix(`/emby`) || PathPrefix(`/mediabrowser`) || PathPrefix(`/socket`) || PathPrefix(`/Videos`) || PathPrefix(`/Items`) || PathPrefix(`/System`) || PathPrefix(`/Users/AuthenticateByName`))",
  "traefik.http.routers.emby-api-http.entrypoints=web",
  "traefik.http.routers.emby-api-http.middlewares=cf-tunnel-https@file,emby-ratelimit@file,emby-sec@file",
  "traefik.http.routers.emby-api-http.priority=10",
  "traefik.http.routers.emby-api-http.service=emby"
]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
