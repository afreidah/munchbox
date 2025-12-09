# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client
#
# Project: Munchbox / Author: Alex Freidah
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
  "traefik.http.routers.deluge.middlewares=authentik@file"
]

# --- Termination ---
kill_timeout = "30s"
