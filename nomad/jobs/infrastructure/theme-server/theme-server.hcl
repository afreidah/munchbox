# -------------------------------------------------------------------------------
# Theme Server — Static CSS Theme Files
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves custom Catppuccin Mocha CSS themes for services that support external
# CSS injection. Provides consistent theming across Sonarr, Radarr, Lidarr,
# Prowlarr, Deluge, and other compatible applications.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "theme-server"
type         = "service"
image        = "registry.munchbox.cc/theme-server:latest"
port         = 8078
static_port  = 8078
host_network = true
size         = "tiny"

# --- Run on large Oracle Cloud nodes ---
constraints = [
  { attribute = "$${meta.cloud}", value = "oracle" },
  { attribute = "$${meta.size}", value = "large" }
]

# --- Health check ---
health_path = "/health"

# --- Traefik routing ---
traefik      = true
traefik_host = "themes.munchbox.cc"

# --- Service tags ---
tags = [
  "infrastructure",
  "themes",
  "css",
  # Internal only - no auth needed for CSS files
  "traefik.http.routers.theme-server.rule=Host(`themes.munchbox.cc`)",
  "traefik.http.routers.theme-server.entrypoints=web,websecure"
]
