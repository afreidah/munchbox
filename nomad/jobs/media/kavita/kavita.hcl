# -------------------------------------------------------------------------------
# Kavita — Self-hosted Digital Library
#
# Project: Munchbox / Author: Alex Freidah
#
# Modern, fast ebook/manga/comic server with built-in reader. Supports EPUB,
# PDF, CBZ/CBR formats with progress tracking and user management.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "kavita"
type  = "service"
image = "jvmilazz0/kavita:0.8.8"
node  = "oraclearm2"
port  = 5000
host_network = true

cpu    = 500
memory = 512

# --- Storage ---
# Fully portable - config and books both on NFS, can run on any node
storage = "ephemeral"
volumes = [
  "/mnt/gdrive-secondary/kavita/config:/kavita/config",
  "/mnt/gdrive-secondary/Books:/books:ro"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "kavita.munchbox.cc"

# --- Health check ---
health_path     = "/"
health_interval = "30s"
health_timeout  = "5s"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "media",
  "books",
  "kavita",
  # HTTPS router middleware
  "traefik.http.routers.kavita.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.kavita-http.rule=Host(`kavita.munchbox.cc`)",
  "traefik.http.routers.kavita-http.entrypoints=web",
  "traefik.http.routers.kavita-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]

# --- Make publicly accessible (skip LAN-only middleware on HTTPS router) ---
traefik_public = true

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
