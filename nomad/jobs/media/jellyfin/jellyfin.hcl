# -------------------------------------------------------------------------------
# Jellyfin Media Server — Open Source Streaming Platform
#
# Project: Munchbox / Author: Alex Freidah
#
# Jellyfin media server with GPU transcoding, Live TV support, and full feature
# access without subscription. Running alongside Emby for Live TV/ErsatzTV.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "jellyfin"
type  = "service"
image = "jellyfin/jellyfin:10.11.5"
port  = 8096
static_port = 8096
host_network = true
node = "nomad-client-01"
cpu    = 3500
memory = 3000

# --- Additional ports ---
extra_ports = [
  { name = "https", port = 8920, static = true }
]

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/jellyfin/config:/config",
  "/opt/nomad/data/jellyfin/cache:/cache",
  "/mnt/gdrive/media/Movies:/media/Movies:ro",
  "/mnt/gdrive/media/TV:/media/TV:ro",
  "/mnt/gdrive/media/Music:/media/Music:ro"
]

# --- Device access for GPU transcoding ---
devices = [
  { host = "/dev/dri", container = "/dev/dri" }
]

# --- Traefik routing ---
traefik      = true
traefik_host = "jellyfin.munchbox.cc"

# --- Health check ---
health_path = "/System/Ping"

# --- Environment ---
env = {
  JELLYFIN_PublishedServerUrl = "https://jellyfin.munchbox.cc"
  TZ                          = "America/Los_Angeles"
}

# --- Service tags (including Traefik routing) ---
# No Authentik - Jellyfin has its own user authentication
tags = [
  "media",
  "jellyfin",
  "streaming",
  # Service definition
  "traefik.http.services.jellyfin.loadbalancer.server.port=8096",
  # HTTPS router (direct LAN access)
  "traefik.http.routers.jellyfin.rule=Host(`jellyfin.munchbox.cc`)",
  "traefik.http.routers.jellyfin.entrypoints=websecure",
  "traefik.http.routers.jellyfin.tls=true",
  "traefik.http.routers.jellyfin.tls.certresolver=letsencrypt",
  # HTTP router (for CF tunnel)
  "traefik.http.routers.jellyfin-http.rule=Host(`jellyfin.munchbox.cc`)",
  "traefik.http.routers.jellyfin-http.entrypoints=web",
  "traefik.http.routers.jellyfin-http.middlewares=cf-tunnel-https@file",
  "traefik.http.routers.jellyfin-http.service=jellyfin"
]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
