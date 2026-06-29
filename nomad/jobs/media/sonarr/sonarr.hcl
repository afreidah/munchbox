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
image        = "linuxserver/sonarr:4.0.17"
port         = 8989
static_port  = 8989
host_network = true
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
size = "medium"
cpu  = 1000

# --- Health check (use /ping to avoid auth failures in logs) ---
health_path = "/ping"

# --- Storage ---
storage       = "local"
storage_path  = "/config"
storage_owner = "1001:1001"
volumes = [
  "/tank:/data"
]

# --- Vault (for PostgreSQL credentials) ---
vault = true

# --- Traefik routing ---
traefik      = true
traefik_host = "sonarr.munchbox.cc"

# --- PostgreSQL configuration ---
templates = [
  { src = "postgres.env.tpl", dest = "secrets/postgres.env", vault = "true", env = "true" }
]

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
  # PostgreSQL connection (credentials injected via template)
  SONARR__POSTGRES__HOST   = "haproxy-postgres.service.consul"
  SONARR__POSTGRES__PORT   = "5433"
  SONARR__POSTGRES__MAINDB = "sonarr_main"
  SONARR__POSTGRES__LOGDB  = "sonarr_log"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS        = "ghcr.io/themepark-dev/theme.park:sonarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME           = "catppuccin-mocha"
  TP_CUSTOM_CSS      = "http://themes.munchbox.cc/css/sonarr.css"
}

# --- Service tags ---
tags = [
  "sonarr",
  "media",
  "arr",
  "traefik.http.routers.sonarr.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.sonarr-http.rule=Host(`sonarr.munchbox.cc`)",
  "traefik.http.routers.sonarr-http.entrypoints=web",
  "traefik.http.routers.sonarr-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
