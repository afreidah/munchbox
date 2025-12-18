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
node  = "nomad-client-02"
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
  # OpenTelemetry tracing to Tempo (gRPC)
  OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
  OTEL_SERVICE_NAME           = "health-checker"
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
  "traefik.http.routers.health-checker-public.rule=Host(`k3s-status.alexfreidah.com`)",
  "traefik.http.routers.health-checker-public.entrypoints=web",
  "traefik.http.routers.health-checker-public.service=health-checker",
  "traefik.http.routers.health-checker-public.middlewares=k3s-status-sec@file",
  "traefik.http.services.health-checker.loadbalancer.server.port=8080",
]
