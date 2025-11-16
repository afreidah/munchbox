# -------------------------------------------------------------------------------
# Temporal — PostgreSQL Database
#
# Project: Munchbox / Author: Alex Freidah
#
# PostgreSQL 15 backend for Temporal workflow engine. Persistent storage
# on stabler node with host networking for simplified connectivity.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-postgres"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal PostgreSQL database backend — persistent storage"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "database"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "db"
    static = 5432
    to     = 5432
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

  service = {
    name     = "temporal-postgres"
    port     = "db"
    provider = "consul"
    tags = [
      "temporal",
      "postgres",
      "database"
    ]
  }

  resources = {
    cpu    = 500
    memory = 512
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
