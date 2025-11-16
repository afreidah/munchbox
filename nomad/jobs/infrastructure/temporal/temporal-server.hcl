# -------------------------------------------------------------------------------
# Temporal — Server with gRPC API
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal server with auto-setup connecting to PostgreSQL backend.
# gRPC API on port 7233 for workflow submissions and queries.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-server"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal server — workflow orchestration engine with gRPC API"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "orchestration"

# --- Resource allocation ---
resource_tier = "large"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "frontend"
    static = 7233
    to     = 7233
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }
]

# --- Restart policy ---
restart_attempts = 10
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "temporal"
  driver = "docker"

  config = {
    image              = "temporalio/auto-setup:1.25.0"
    image_pull_timeout = "10m"
    ports              = ["frontend"]
  }

  env = {
    TZ             = "UTC"
    DB             = "postgres12_pgx"
    DB_PORT        = "5432"
    POSTGRES_USER  = "temporal"
    POSTGRES_PWD   = "temporal"
    POSTGRES_SEEDS = "localhost"
  }

  service = {
    name     = "temporal-frontend"
    port     = "frontend"
    provider = "consul"
    tags = [
      "temporal",
      "frontend",
      "grpc"
    ]
  }

  resources = {
    cpu    = 1000
    memory = 1024
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
