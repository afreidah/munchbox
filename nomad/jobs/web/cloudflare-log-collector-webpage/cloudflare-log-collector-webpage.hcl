# -------------------------------------------------------------------------------
# cloudflare-log-collector-webpage — Project Documentation Website
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the cloudflare-log-collector Hugo project website. Public-facing via
# Cloudflare tunnel, no oauth2-proxy.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "cloudflare-log-collector-webpage"
type  = "service"
image = "registry.munchbox.cc/cloudflare-log-collector-web:v0.1.15"
port  = 80
node  = "any"
host_network = false
size  = "tiny"
count = 3
storage = "ephemeral"

# --- Placement: one instance per node ---
constraints = [
  { attribute = "", operator = "distinct_hosts", value = "true" }
]

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/"

# --- Service tags ---
tags = [
  "web",
  "cloudflare-log-collector",
  "documentation",
  "traefik.http.routers.cflog-web.rule=Host(`cloudflare-log-collector.munchbox.cc`)",
  "traefik.http.routers.cflog-web.entrypoints=web",
  "traefik.http.routers.cflog-web.service=cloudflare-log-collector-webpage",
  "traefik.http.routers.cflog-web.priority=100",
]
