# -------------------------------------------------------------------------------
# Temporal PostgreSQL Database — Persistent Backend for Workflow Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# PostgreSQL 15 backend for Temporal workflow orchestration. Runs in Consul
# Connect service mesh for zero-trust database access. Persistent storage on
# stabler node with host volume mount.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-postgres"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal PostgreSQL database backend with Connect mesh isolation"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier1"
category           = "database"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
network_preset = "bridge"

ports = [
  {
    name = "db"
    to   = 5432
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

# --- Persistent storage volume ---
volume = {
  name       = "temporal-postgres-data"
  type       = "host"
  source     = "temporal-postgres-data"
  mount_path = "/var/lib/postgresql/data"
  read_only  = false
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "postgres"
  driver = "docker"

  config = {
    image              = "postgres:15-alpine"
    image_pull_timeout = "10m"
    ports              = ["db"]
  }

  env = {
    TZ                = "UTC"
    POSTGRES_USER     = "temporal"
    POSTGRES_PASSWORD = "temporal"
    POSTGRES_DB       = "temporal"
  }

  resources = {
    cpu    = 500
    memory = 512
  }
}

# --- Consul Connect service mesh ---
consul_connect_enabled = true

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "db"
standard_service_port_number = 5432
standard_http_check_enabled  = false

additional_tags = [
  "temporal",
  "postgres",
  "database"
]

# --- Traefik routing ---
traefik_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
