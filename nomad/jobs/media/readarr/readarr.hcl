# -------------------------------------------------------------------------------
# Readarr — Book Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Monitors RSS feeds and interfaces with indexers to automatically grab ebooks
# and audiobooks. Integrates with Deluge for downloads and manages library
# organization. Works with Kavita for reading.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "readarr"
type         = "service"
image        = "linuxserver/readarr:0.4.19-nightly"
port         = 8787
static_port  = 8787
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
size         = "medium"

# --- Health check (use /ping to avoid auth failures in logs) ---
health_path  = "/ping"

# --- Storage ---
storage       = "local"
storage_path  = "/config"
storage_owner = "1001:1001"
volumes = [
  "/tank:/data",
  "/mnt/gdrive-secondary/Books:/books"
]

# --- Vault (for PostgreSQL credentials) ---
vault = true

# --- Traefik routing ---
traefik      = true
traefik_host = "readarr.munchbox.cc"

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
  READARR__POSTGRES__HOST   = "haproxy-postgres.service.consul"
  READARR__POSTGRES__PORT   = "5433"
  READARR__POSTGRES__MAINDB = "readarr_main"
  READARR__POSTGRES__LOGDB  = "readarr_log"
  # Custom Catppuccin Mocha theme via theme-server
  DOCKER_MODS        = "ghcr.io/themepark-dev/theme.park:readarr"
  TP_COMMUNITY_THEME = "true"
  TP_THEME           = "catppuccin-mocha"
  TP_CUSTOM_CSS      = "http://themes.munchbox.cc/css/readarr.css"
}

# --- Service tags ---
tags = [
  "readarr",
  "media",
  "arr",
  "traefik.http.routers.readarr.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.readarr-http.rule=Host(`readarr.munchbox.cc`)",
  "traefik.http.routers.readarr-http.entrypoints=web",
  "traefik.http.routers.readarr-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
