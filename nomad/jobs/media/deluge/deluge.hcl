# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client
#
# Project: Munchbox / Author: Alex Freidah
#
# Lightweight BitTorrent client with web UI for remote management. Handles
# downloads from Sonarr, Radarr, and Lidarr with category-based organization.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "deluge"
type         = "service"
image        = "linuxserver/deluge:latest"
port         = 8112
static_port  = 8112
host_network = true
size         = "medium"
memory       = 1024
cpu          = 1500

# --- Storage ---
storage      = "local"           # Local, not NFS
storage_path = "/config"
volumes = [
  "/mnt/gdrive/nomad_deluge_downloads:/downloads",
  "/mnt/gdrive/nomad_deluge_completed:/completed"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "deluge.munchbox.cc"

# --- Environment variables ---
env = {
  PUID = "1001"
  PGID = "1001"
  TZ   = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "deluge",
  "torrent",
  "media",
  # HTTPS router (direct LAN access)
  "traefik.http.routers.deluge.middlewares=authentik@file",
  # HTTP router (Cloudflare tunnel - TLS terminated at CF edge)
  "traefik.http.routers.deluge-http.rule=Host(`deluge.munchbox.cc`)",
  "traefik.http.routers.deluge-http.entrypoints=web",
  "traefik.http.routers.deluge-http.middlewares=cf-tunnel-https@file,authentik@file"
]

# --- Vault integration ---
vault = true

# --- Templates ---
templates = [
  { src = "web.conf.tpl", dest = "/config/web.conf", vault = true }
]

# --- Termination ---
kill_timeout = "30s"
