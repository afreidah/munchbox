# -------------------------------------------------------------------------------
# Temporal Server — Workflow Orchestration Engine with gRPC API
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal server with auto-setup connecting to PostgreSQL backend via Consul
# Connect mesh. Exposes gRPC API (port 7233) for workflow submissions and
# queries. Runs in service mesh for zero-trust connectivity to PostgreSQL.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-server"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal workflow orchestration engine with Connect mesh PostgreSQL access"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier1"
category           = "orchestration"

# --- Resource allocation ---
resource_tier = "large"

# --- Network configuration ---
network_preset = "bridge"

ports = [
  {
    name   = "frontend"
    static = 7233
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

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
    TZ                              = "UTC"
    DB                              = "postgres12_pgx"
    DB_PORT                         = "5432"
    POSTGRES_USER                   = "temporal"
    POSTGRES_PWD                    = "temporal"
    POSTGRES_SEEDS                  = "127.0.0.1"
    SKIP_DB_CREATE                  = "true"
    SKIP_DEFAULT_NAMESPACE_CREATION = "false"
    BIND_ON_IP                      = "0.0.0.0"
  }

  resources = {
    cpu    = 1000
    memory = 1024
  }
}

# --- Consul Connect service mesh ---
consul_connect_enabled = true

connect_upstreams = [
  {
    destination_name = "temporal-postgres"
    local_bind_port  = 5432
  }
]

# --- Standard service configuration ---
standard_service_enabled          = true
standard_service_port             = "frontend"
standard_service_port_number      = 7233
standard_http_check_enabled       = false
standard_service_address_mode     = "host"

additional_tags = [
  "temporal",
  "frontend",
  "grpc"
]

# --- Traefik routing ---
traefik_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
