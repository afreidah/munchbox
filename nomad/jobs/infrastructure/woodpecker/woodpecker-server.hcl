# -------------------------------------------------------------------------------
# Woodpecker Server — CI/CD Pipeline Orchestrator
#
# Project: Munchbox / Author: Alex Freidah
#
# Woodpecker CI server connects to GitHub via OAuth for repository access and
# webhook events. Manages pipeline execution, stores build history, and provides
# web UI for monitoring. Agents connect to execute actual build workloads.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "woodpecker-server"
type  = "service"
image = "woodpeckerci/woodpecker-server:v3.12.0"
port  = 8000
node  = "oraclenode1"
static_port = 8000
size  = "small"
host_network = true

# --- Additional ports ---
extra_ports = [
  { name = "grpc", port = 9000, static = true }
]

# --- Storage ---
storage = "ephemeral"

# --- Traefik routing ---
traefik      = true
traefik_host = "woodpecker.munchbox.cc"

# --- Health check ---
health_path = "/healthz"

# --- Vault integration ---
vault = true

# --- Templates (inject secrets from Vault) ---
templates = [
  { src = "woodpecker-server.env.tpl", dest = "/secrets/woodpecker.env", env = true, vault = true }
]

# --- Environment variables ---
env = {
  WOODPECKER_HOST            = "https://woodpecker.munchbox.cc"
  WOODPECKER_OPEN            = "false"
  WOODPECKER_ADMIN           = "alex"
  WOODPECKER_GITHUB          = "false"
  WOODPECKER_FORGEJO         = "true"
  WOODPECKER_FORGEJO_URL     = "https://git.munchbox.cc"
  WOODPECKER_DATABASE_DRIVER      = "postgres"
  WOODPECKER_GRPC_ADDR            = "0.0.0.0:9000"
  WOODPECKER_LOG_LEVEL            = "info"
  TZ                              = "America/Los_Angeles"
  # OpenTelemetry tracing to Tempo
  OTEL_EXPORTER_OTLP_ENDPOINT     = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL     = "grpc"
  OTEL_SERVICE_NAME               = "woodpecker-server"
}

# --- Service tags ---
tags = [
  "woodpecker",
  "ci",
  "infrastructure",
  # Main UI router - protected by Authentik
  "traefik.http.routers.woodpecker-server.rule=Host(`woodpecker.munchbox.cc`) && !PathPrefix(`/api`) && !PathPrefix(`/hook`)",
  "traefik.http.routers.woodpecker-server.middlewares=authentik@file",
  # API/webhook router - no auth (agents, GitHub webhooks need direct access)
  "traefik.http.routers.woodpecker-api.rule=Host(`woodpecker.munchbox.cc`) && (PathPrefix(`/api`) || PathPrefix(`/hook`))",
  "traefik.http.routers.woodpecker-api.entrypoints=websecure",
  "traefik.http.routers.woodpecker-api.tls.certresolver=letsencrypt",
  "traefik.http.routers.woodpecker-api.service=woodpecker-server",
  # HTTP router for CF tunnel (UI only)
  "traefik.http.routers.woodpecker-server-http.rule=Host(`woodpecker.munchbox.cc`) && !PathPrefix(`/api`) && !PathPrefix(`/hook`)",
  "traefik.http.routers.woodpecker-server-http.entrypoints=web",
  "traefik.http.routers.woodpecker-server-http.middlewares=cf-tunnel-https@file,authentik@file"
]

# --- Termination ---
kill_timeout = "30s"
