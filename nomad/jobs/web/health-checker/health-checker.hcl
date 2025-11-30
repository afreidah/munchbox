# -------------------------------------------------------------------------------
# Health Checker — Internal Service Health Monitoring
#
# Project: Munchbox / Author: Alex Freidah
#
# Health checker service for cluster monitoring. Monitors cron service health
# and exposes status via HTTP endpoint at k3s-status.alexfreidah.com.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "health-checker"
type  = "service"
image = "registry.munchbox.cc/health-checker:latest"
port  = 8080
host_network = true
size = "small"
storage = "ephemeral"

# --- Volume mounts ---
volumes = [
  "/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro"
]

# --- Environment variables ---
env = {
  SERVICE  = "cron"
  PORT     = "8080"
  INTERVAL = "10"
}

# --- Traefik integration ---
traefik = true
traefik_public = true
traefik_host = "k3s-status.alexfreidah.com"
health_path = "/health"

# --- Service tags (override pack defaults) ---
tags = [
  "monitoring",
  "health",
  "go",
  "traefik.http.routers.health-checker.entrypoints=web",
  "traefik.http.routers.health-checker.middlewares=k3s-status-sec@file"
]
