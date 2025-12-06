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

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/health"

# --- Service tags (custom routing via cloudflared) ---
tags = [
  "monitoring",
  "health",
  "go",
  "traefik.http.routers.health-checker-public.rule=Host(`k3s-status.alexfreidah.com`)",  # ← Different name!
  "traefik.http.routers.health-checker-public.entrypoints=web",
  "traefik.http.routers.health-checker-public.middlewares=k3s-status-sec@file",
  "traefik.http.services.health-checker.loadbalancer.server.port=8080",
]
