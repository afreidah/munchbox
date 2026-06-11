# -------------------------------------------------------------------------------
# Munchbox Dashboard — Hugo Static Site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the Munchbox Hugo-Dash static dashboard through NGINX. Provides a
# centralized starting point for operational web interfaces such as Nomad,
# Consul, Grafana, and Proxmox.
# -------------------------------------------------------------------------------

# --- General Settings ---
name         = "dashboard"
type         = "service"
image        = "registry.munchbox.cc/dash:latest"
port         = 80
host_network = false
node         = "any"
size         = "tiny"
cpu          = 50
memory       = 32
storage      = "ephemeral"

# --- Placement: home cluster only (TODO: see issue tracking why
# CF-tunnel + oauth2-proxy auth flow breaks when this lands behind WG
# on an Oracle node — single curl works, browser auth flow returns 502)
constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }
]

# --- Traefik integration ---
traefik      = true
traefik_host = "dashboard.munchbox.cc"
health_path  = "/"

# --- Service tags ---
tags = [
  "web",
  "dashboard",
  "nginx",
  "hugo",
  "traefik.http.routers.dashboard.tls=true",
  "traefik.http.routers.dashboard.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.dashboard-http.rule=Host(`dashboard.munchbox.cc`)",
  "traefik.http.routers.dashboard-http.entrypoints=web",
  "traefik.http.routers.dashboard-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
]
