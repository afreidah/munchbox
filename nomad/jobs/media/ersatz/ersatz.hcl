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
image = "jasongdove/ersatztv:v26.3.0"
port  = 8409
static_port = 8409
host_network = true
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
cpu    = 3500
memory = 4000

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/opt/nomad/data/ersatztv/config:/config",
  "/opt/nomad/data/ersatztv/transcode:/transcode",
  "/tank/media/Movies:/media/Movies:ro",
  "/tank/media/TV:/media/TV:ro"
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
traefik_host = "ersatz.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment variables ---
env = {
  TZ                         = "America/Los_Angeles"
  NVIDIA_VISIBLE_DEVICES     = "all"
  NVIDIA_DRIVER_CAPABILITIES = "all"
}

# --- Service tags ---
tags = [
  "media",
  "ersatztv",
  "streaming",
  "traefik.http.routers.ersatztv.middlewares=oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.ersatztv-http.rule=Host(`ersatz.munchbox.cc`)",
  "traefik.http.routers.ersatztv-http.entrypoints=web",
  "traefik.http.routers.ersatztv-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file"
]

# --- Termination ---
kill_timeout = "30s"
