# -------------------------------------------------------------------------------
# Radarr — Movie Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Monitors RSS feeds and interfaces with indexers to automatically grab movies.
# Integrates with Deluge for downloads and manages movie library organization.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "radarr"
type        = "service"
image       = "linuxserver/radarr:6.1.1"
port        = 7878
static_port = 7878
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
size   = "medium"
memory = 160

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
traefik_host = "radarr.munchbox.cc"

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
  RADARR__POSTGRES__HOST   = "haproxy-postgres.service.consul"
  RADARR__POSTGRES__PORT   = "5433"
  RADARR__POSTGRES__MAINDB = "radarr_main"
  RADARR__POSTGRES__LOGDB  = "radarr_log"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS        = "ghcr.io/themepark-dev/theme.park:radarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME           = "catppuccin-mocha"
  TP_CUSTOM_CSS      = "http://themes.munchbox.cc/css/radarr.css"
}

# --- Service tags ---
tags = [
  "radarr",
  "media",
  "arr",
  "traefik.http.routers.radarr.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.radarr-http.rule=Host(`radarr.munchbox.cc`)",
  "traefik.http.routers.radarr-http.entrypoints=web",
  "traefik.http.routers.radarr-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
