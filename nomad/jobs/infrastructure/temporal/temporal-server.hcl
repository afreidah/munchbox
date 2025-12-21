# -------------------------------------------------------------------------------
# Temporal Server — Workflow Orchestration Engine with gRPC API
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal server with auto-setup connecting to PostgreSQL backend via Consul
# DNS. Exposes gRPC API (port 7233) for workflow submissions and queries.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "temporal-server"
type  = "service"
image = "temporalio/auto-setup:1.29.1"
port  = 7233
static_port = 7233
host_network = true
node = "stabler.munchbox.cc"
size = "large"
storage = "ephemeral"

# --- Environment variables ---
env = {
  TZ                              = "UTC"
  DB                              = "postgres12_pgx"
  DB_PORT                         = "5432"
  POSTGRES_SEEDS                  = "postgres-primary.service.consul"
  SKIP_DB_CREATE                  = "true"
  SKIP_SCHEMA_SETUP               = "false"  # Temporarily enabled to run migration from 1.14 to 1.18
  SKIP_DEFAULT_NAMESPACE_CREATION = "true"
  BIND_ON_IP                      = "0.0.0.0"
  # OpenTelemetry tracing to Tempo (gRPC)
  OTEL_EXPORTER_OTLP_ENDPOINT     = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL     = "grpc"
  OTEL_SERVICE_NAME               = "temporal"
}

# --- Vault integration ---
vault = true

# --- Templates (inject secrets from Vault) ---
templates = [
  { src = "temporal.env.tpl", dest = "/secrets/temporal.env", env = true, vault = true }
]

# --- Traefik integration ---
traefik = false

# --- Health check (disabled for gRPC) ---
health_type = "none"

# --- Service tags ---
tags = [
  "temporal",
  "frontend",
  "grpc"
]

# --- Resources override ---
cpu = 300      # Reduced from 1000 - actual usage <1%
memory = 256   # Reduced from 1024 - actual usage 81MB

# --- DNS configuration ---
dns = ["192.168.68.64", "192.168.68.62"]
