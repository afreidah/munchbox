# -------------------------------------------------------------------------------
# Temporal Web UI — Workflow Monitoring and Management Console
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based interface for Temporal workflow monitoring and management. Connects
# to Temporal server gRPC API via Consul DNS. Exposed via Traefik for browser
# access with bridge networking.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "temporal-ui"
type  = "service"
image = "temporalio/ui:2.44.1"
port  = 8080
host_network = true
size = "small"
storage = "ephemeral"

# --- Placement ---
node = "any"

# --- Environment variables ---
env = {
  TZ                                    = "UTC"
  TEMPORAL_ADDRESS                      = "temporal-server.service.consul:7233"
  TEMPORAL_CORS_ORIGINS                 = "https://temporal.munchbox.cc"
  TEMPORAL_CSRF_COOKIE_INSECURE         = "false"
  TEMPORAL_TLS_CA_PATH                  = ""
  TEMPORAL_TLS_CERT_PATH                = ""
  TEMPORAL_TLS_KEY_PATH                 = ""
  TEMPORAL_TLS_ENABLE_HOST_VERIFICATION = "false"
  TEMPORAL_TLS_SERVER_NAME              = ""
}

# --- Traefik integration ---
traefik = true
traefik_host = "temporal.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Service tags ---
tags = [
  "temporal",
  "ui",
  "monitoring",
  "traefik.http.routers.temporal-ui.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.temporal-ui-http.rule=Host(`temporal.munchbox.cc`)",
  "traefik.http.routers.temporal-ui-http.entrypoints=web",
  "traefik.http.routers.temporal-ui-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]

# --- DNS configuration ---
dns = ["192.168.68.64", "192.168.68.62"]

# --- Exclude Oracle nodes (unreliable WAN link) ---
constraints = [
  { attribute = "$${node.unique.name}", operator = "!=", value = "oraclenode1" },
  { attribute = "$${node.unique.name}", operator = "!=", value = "oraclenode2" }
]
