# -------------------------------------------------------------------------------
# Temporal Server — Workflow Orchestration Engine with gRPC API
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal server connecting to PostgreSQL backend via Consul DNS. Uses env vars
# for TLS configuration. Schema migrations are handled separately.
# Exposes gRPC API (port 7233) for workflow submissions and queries.
# -------------------------------------------------------------------------------

# --- Job directory (for template files) ---
job_dir = "/home/afreidah/tools/munchbox/nomad/jobs/infrastructure/temporal"

# --- General Settings ---
name  = "temporal-server"
type  = "service"
image = "temporalio/server:1.29.1"
port  = 7233
static_port = 7233
host_network = true
node = "stabler.munchbox.cc"
size = "large"
storage = "ephemeral"

# --- Environment variables ---
env = {
  TZ                          = "UTC"
  SERVICES                    = "frontend,history,matching,worker"
  # OpenTelemetry tracing to Tempo (gRPC)
  OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
  OTEL_SERVICE_NAME           = "temporal"
}

# --- Vault integration ---
vault = true

# --- Templates (inject secrets from Vault as env vars) ---
templates = [
  { src = "temporal-env.tpl", dest = "/secrets/temporal.env", env = true, vault = true },
  { src = "ca.crt.tpl", dest = "/secrets/ca.crt", vault = true }
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
cpu = 500
memory = 512

# --- DNS configuration ---
# Uses goren's dnsmasq which can resolve Consul service names
dns = ["192.168.68.60"]
