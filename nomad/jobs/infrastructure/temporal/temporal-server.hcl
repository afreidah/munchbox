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
name         = "temporal-server"
type         = "service"
image        = "temporalio/server:1.31.2"
port         = 7233
static_port  = 7233
host_network = true
node         = "nomad-client-03"
size         = "large"
storage      = "ephemeral"

# --- Environment variables ---
env = {
  TZ       = "UTC"
  SERVICES = "frontend,history,matching,worker"
  # OpenTelemetry tracing to Tempo (gRPC)
  OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
  OTEL_SERVICE_NAME           = "temporal"

  # --- Prometheus listener. The server renders its config from an embedded
  #     template at startup, which maps this to
  #     global.metrics.prometheus.listenAddress; there is no config file to
  #     mount. Serves /metrics for schedule, workflow and task-queue metrics. ---
  PROMETHEUS_ENDPOINT = "0.0.0.0:9464"
}

# --- Metrics port. Static because the scrape-port tag below is a literal and
#     cannot reference a dynamically allocated port. ---
extra_ports = [
  { name = "metrics", port = 9464, static = true }
]

# --- Vault integration ---
vault      = true
vault_role = "temporal-server"

# --- Templates (inject secrets from Vault as env vars) ---
templates = [
  { src = "temporal-env.tpl", dest = "/secrets/temporal.env", env = true, vault = true },
  { src = "ca.crt.tpl", dest = "/secrets/ca.crt", vault = true },
  # --- 1.30+ requires the dynamic-config file to exist (1.29 shipped an empty one in-image) ---
  { src = "dynamicconfig.yaml", dest = "/etc/temporal/config/dynamicconfig/docker.yaml" }
]

# --- Traefik integration ---
traefik = false

# --- Health check (disabled for gRPC) ---
health_type = "none"

# --- Service tags ---
tags = [
  # --- the service port is gRPC, so scrape-port redirects Prometheus to the
  #     metrics listener ---
  "metrics",
  "scrape-port=9464",
  "temporal",
  "frontend",
  "grpc"
]

# --- Resources override ---
cpu    = 500
memory = 512
