# -------------------------------------------------------------------------------
# Prowlarr — Indexer Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Centralized indexer manager for the *arr stack. Syncs indexer configurations
# to Sonarr, Radarr, and Lidarr. Uses FlareSolverr for Cloudflare bypass.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "prowlarr"
type         = "service"
image        = "linuxserver/prowlarr:2.3.0"
port         = 9696
static_port  = 9696
host_network = true
size         = "medium"
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
memory       = 300
cpu          = 1000

# --- Health check (use /ping to avoid auth failures in logs) ---
health_path  = "/ping"

# --- Storage ---
storage      = "local"
storage_path = "/config"

# --- Traefik routing ---
traefik      = true
traefik_host = "prowlarr.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS   = "ghcr.io/themepark-dev/theme.park:prowlarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME      = "catppuccin-mocha"
  TP_CUSTOM_CSS = "http://themes.munchbox.cc/css/prowlarr.css"
}

# --- Service tags ---
tags = [
  "prowlarr",
  "media",
  "arr",
  "traefik.http.routers.prowlarr.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.prowlarr-http.rule=Host(`prowlarr.munchbox.cc`)",
  "traefik.http.routers.prowlarr-http.entrypoints=web",
  "traefik.http.routers.prowlarr-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file"
]
