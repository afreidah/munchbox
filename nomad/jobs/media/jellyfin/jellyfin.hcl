# -------------------------------------------------------------------------------
# Jellyfin Media Server — Open Source Streaming Platform
#
# Project: Munchbox / Author: Alex Freidah
#
# Jellyfin media server with GPU transcoding, Live TV support, and full feature
# access without subscription. Running alongside Emby for Live TV/ErsatzTV.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "jellyfin"
type         = "service"
image        = "jellyfin/jellyfin:10.11.10"
port         = 8096
static_port  = 8096
host_network = true
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
cpu    = 3500
memory = 4000

# --- Additional ports ---
extra_ports = [
  { name = "https", port = 8920, static = true }
]

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/jellyfin/config:/config",
  "/opt/nomad/data/jellyfin/cache:/cache",
  "/tank/media/Movies:/media/Movies:ro",
  "/tank/media/TV:/media/TV:ro",
  "/tank/media/Music:/media/Music:ro"
]

# --- NVIDIA GPU transcoding ---
runtime = "nvidia"
devices = [
  { host = "/dev/nvidia0", container = "/dev/nvidia0" },
  { host = "/dev/nvidiactl", container = "/dev/nvidiactl" },
  { host = "/dev/nvidia-uvm", container = "/dev/nvidia-uvm" },
  { host = "/dev/nvidia-uvm-tools", container = "/dev/nvidia-uvm-tools" }
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
  NVIDIA_VISIBLE_DEVICES      = "all"
  NVIDIA_DRIVER_CAPABILITIES  = "all"
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
  "traefik.http.routers.jellyfin.middlewares=jellyfin-ratelimit@file",
  # HTTP router (for CF tunnel)
  "traefik.http.routers.jellyfin-http.rule=Host(`jellyfin.munchbox.cc`)",
  "traefik.http.routers.jellyfin-http.entrypoints=web",
  "traefik.http.routers.jellyfin-http.middlewares=cf-tunnel-https@file,jellyfin-ratelimit@file",
  "traefik.http.routers.jellyfin-http.service=jellyfin"
]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
