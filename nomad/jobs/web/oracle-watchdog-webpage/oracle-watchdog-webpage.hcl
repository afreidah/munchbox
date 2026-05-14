# -------------------------------------------------------------------------------
# oracle-watchdog-webpage — Project Documentation Website
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the oracle-watchdog Hugo project website. Public-facing via
# Cloudflare tunnel, no oauth2-proxy.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "oracle-watchdog-webpage"
type  = "service"
image = "registry.munchbox.cc/oracle-watchdog-web:v1.3.0"
port  = 80
node  = "any"
host_network = false
size   = "tiny"
cpu    = 50
memory = 32
count  = 3
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
  "oracle-watchdog",
  "documentation",
  "traefik.http.routers.owdog-web.rule=Host(`oracle-watchdog.munchbox.cc`)",
  "traefik.http.routers.owdog-web.entrypoints=web",
  "traefik.http.routers.owdog-web.service=oracle-watchdog-webpage",
  "traefik.http.routers.owdog-web.priority=100",
]
