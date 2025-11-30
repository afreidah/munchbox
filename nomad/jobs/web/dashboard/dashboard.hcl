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
name  = "dashboard"
type  = "service"
image = "registry.munchbox.cc/dash:latest"
port  = 80
host_network = false
size = "tiny"
storage = "ephemeral"

# --- Traefik integration ---
traefik = true
traefik_host = "dashboard.munchbox.cc"
health_path = "/"

# --- Service tags ---
tags = [
  "web",
  "dashboard",
  "nginx",
  "hugo"
]
