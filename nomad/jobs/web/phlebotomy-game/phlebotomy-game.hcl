# -------------------------------------------------------------------------------
# Phlebotomy Game - Blood Collection Tube Study Application
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based flashcard game for studying blood collection tube order of draw,
# colors, names, and contents. Provides multiple game modes including multiple
# choice quiz, drag-and-drop ordering, and memory matching. Tube data can be
# customized by editing tubes.json in this directory.
# -------------------------------------------------------------------------------

# --- General Settings ---
name         = "phlebotomy-game"
type         = "service"
image        = "registry.munchbox.cc/phlebotomy-game:latest"
port         = 8080
host_network = false
size         = "tiny"
storage      = "ephemeral"

# --- Traefik integration ---
traefik      = true
traefik_host = "study.munchbox.cc"
health_path  = "/health"

# --- Custom tube data ---
templates = [
  { src = "tubes.json", dest = "/data/tubes.json" }
]

# --- Service tags ---
tags = [
  "web",
  "education",
  "phlebotomy",
  "traefik.http.routers.phlebotomy-game.tls=true",
  "traefik.http.routers.phlebotomy-game.tls.certresolver=letsencrypt",
  "traefik.http.routers.phlebotomy-game.middlewares=oauth2-proxy@file,umami-tracking@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.phlebotomy-game-http.rule=Host(`study.munchbox.cc`)",
  "traefik.http.routers.phlebotomy-game-http.entrypoints=web",
  "traefik.http.routers.phlebotomy-game-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file,umami-tracking@file",
]
