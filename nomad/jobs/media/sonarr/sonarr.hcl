# -------------------------------------------------------------------------------
# Sonarr — TV Show Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Monitors RSS feeds and interfaces with indexers to automatically grab TV show
# episodes. Integrates with Deluge for downloads and manages library organization.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "sonarr"
type         = "service"
image        = "linuxserver/sonarr:4.0.16"
port         = 8989
static_port  = 8989
host_network = true
node         = "nomad-client-01"
size         = "medium"
cpu          = 1000

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
traefik_host = "sonarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS   = "ghcr.io/themepark-dev/theme.park:sonarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME      = "catppuccin-mocha"
  TP_CUSTOM_CSS = "http://themes.munchbox.cc/css/sonarr.css"
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
