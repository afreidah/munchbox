# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "deluge"
type  = "service"
image = "linuxserver/deluge:latest"
port  = 8112
static_port = 8112
host_network = true
node = "nomad-client-02"
size = "small"

# --- Storage ---
storage = "ephemeral"
volumes = [
  "/mnt/gdrive/nomad_deluge_config:/config",
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
  TZ = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "deluge",
  "torrent",
  "media"
]

# --- Termination ---
kill_timeout = "30s"
