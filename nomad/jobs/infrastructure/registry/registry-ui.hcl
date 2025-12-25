# -------------------------------------------------------------------------------
# Docker Registry UI — Web Interface for Registry Mirror
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based interface for browsing Docker registry contents. Provides visual
# access to stored images and tags with read-only access.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "registry-ui"
type  = "service"
image = "joxit/docker-registry-ui:2.5.7-debian"
port  = 80
size = "small"

# --- Storage ---
storage = "ephemeral"

# --- Traefik routing ---
traefik      = true
traefik_host = "registry-ui.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment variables ---
env = {
  NGINX_PROXY_PASS_URL = "http://192.168.68.61:5000"
  SINGLE_REGISTRY      = "true"
  REGISTRY_TITLE       = "Munchbox Docker Registry"
  DELETE_IMAGES        = "false"
  TZ                   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "registry-ui",
  "docker",
  "ui",
  "infrastructure",
  "traefik.http.routers.registry-ui.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.registry-ui-http.rule=Host(`registry-ui.munchbox.cc`)",
  "traefik.http.routers.registry-ui-http.entrypoints=web",
  "traefik.http.routers.registry-ui-http.middlewares=cf-tunnel-https@file,authentik@file"
]

# --- Termination ---
kill_timeout = "30s"
