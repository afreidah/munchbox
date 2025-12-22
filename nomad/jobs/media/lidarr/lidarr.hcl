# -------------------------------------------------------------------------------
# Lidarr — Music Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Monitors RSS feeds and interfaces with indexers to automatically grab music.
# Integrates with Deluge for downloads and manages music library organization.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "lidarr"
type         = "service"
image        = "linuxserver/lidarr:3.1.0"
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
  "/mnt/gdrive:/data"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "lidarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS   = "ghcr.io/themepark-dev/theme.park:lidarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME      = "catppuccin-mocha"
  TP_CUSTOM_CSS = "http://themes.munchbox.cc/css/lidarr.css"
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
