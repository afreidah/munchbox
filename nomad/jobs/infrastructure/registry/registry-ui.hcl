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
image = "joxit/docker-registry-ui@sha256:9e561fbe4fb1460c383e1d33e76f87c4cf4cddfd78adb02db9fb1d039b5c1e15"
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
  "traefik.http.routers.registry-ui.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.registry-ui-http.rule=Host(`registry-ui.munchbox.cc`)",
  "traefik.http.routers.registry-ui-http.entrypoints=web",
  "traefik.http.routers.registry-ui-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file,umami-tracking@file"
]

# --- Termination ---
kill_timeout = "30s"
