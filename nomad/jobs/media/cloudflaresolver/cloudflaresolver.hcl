# -------------------------------------------------------------------------------
# FlareSolverr — Cloudflare Bypass Proxy
#
# Project: Munchbox / Author: Alex Freidah
#
# Headless browser proxy that solves Cloudflare challenges for indexers. Used by
# Prowlarr to access sites protected by anti-bot measures.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "cloudflaresolverr"
type  = "service"
image = "ghcr.io/flaresolverr/flaresolverr:v3.5.0"
constraints = [
  { attribute = "$${meta.gpu}", operator = "=", value = "true" }
]
port   = 8191
size   = "medium"
memory = 512

# --- Networking ---
host_network = true
static_port  = 8191

# --- Storage ---
storage = "ephemeral"

# --- Traefik routing ---
traefik          = false
register_service = true

# --- Environment variables ---
env = {
  LOG_LEVEL = "info"
  TZ        = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "flaresolverr",
  "proxy"
]
