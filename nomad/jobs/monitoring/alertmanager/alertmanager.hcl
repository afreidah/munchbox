# -------------------------------------------------------------------------------
# Alertmanager — Alert Routing and Notification
#
# Project: Munchbox / Author: Alex Freidah
#
# Handles alerts from Prometheus with deduplication, grouping, and routing to
# Telegram notification channels. Integrates with Vault for secure credential
# retrieval via Nomad workload identity.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "alertmanager"
image        = "prom/alertmanager:v0.33.1"
port         = 9093
size         = "tiny"
cpu          = 50
memory       = 64
host_network = true
vault        = true

# --- Additional ports ---
extra_ports = [
  { name = "cluster", port = 9094 }
]

# --- Placement: pinned to nomad-client-05 ---
type = "service"
node = "nomad-client-05"

# --- Traefik routing ---
traefik      = true
traefik_host = "alertmanager.munchbox.cc"

# --- Health check ---
health_path = "/-/ready"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
  # OpenTelemetry tracing to Tempo (gRPC)
  OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
  OTEL_SERVICE_NAME           = "alertmanager"
}

# --- Container arguments ---
args = [
  "--config.file=/etc/alertmanager/config/alertmanager.yml",
  "--storage.path=/alertmanager",
  "--web.listen-address=0.0.0.0:9093",
  "--cluster.listen-address=0.0.0.0:9094",
  "--cluster.peer=alertmanager.service.consul:9094",
  "--web.external-url=https://alertmanager.munchbox.cc"
]

# --- Configuration templates ---
templates = [
  { src = "alertmanager.yml.tpl", dest = "/etc/alertmanager/config/alertmanager.yml", vault = true }
]

# --- Service tags ---
tags = [
  "monitoring",
  "metrics",
  "alertmanager",
  "alerts",
  "traefik.http.routers.alertmanager.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.alertmanager-http.rule=Host(`alertmanager.munchbox.cc`)",
  "traefik.http.routers.alertmanager-http.entrypoints=web",
  "traefik.http.routers.alertmanager-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
