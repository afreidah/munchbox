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
  WOODPECKER_ADMIN           = "afreidah"
  WOODPECKER_GITHUB          = "true"
  WOODPECKER_ORGS            = "afreidah"
  WOODPECKER_DATABASE_DRIVER = "postgres"
  WOODPECKER_GRPC_ADDR       = "0.0.0.0:9000"
  WOODPECKER_LOG_LEVEL       = "info"
  TZ                         = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "woodpecker",
  "ci",
  "infrastructure",
  "traefik.http.routers.woodpecker-server.middlewares=authentik@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.woodpecker-server-http.rule=Host(`woodpecker.munchbox.cc`)",
  "traefik.http.routers.woodpecker-server-http.entrypoints=web",
  "traefik.http.routers.woodpecker-server-http.middlewares=cf-tunnel-https@file,authentik@file"
]

# --- Termination ---
kill_timeout = "30s"
