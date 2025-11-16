# -------------------------------------------------------------------------------
# Temporal — Web UI
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal web UI for workflow monitoring and management. Connects to
# Temporal server gRPC API on port 7233. Service discovery via Consul.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "temporal-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Temporal UI — workflow monitoring and management console"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "orchestration"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 8080
    to     = 8080
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
restart_attempts = 5
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "ui"
  driver = "docker"

  config = {
    image              = "temporalio/ui:2.31.1"
    image_pull_timeout = "10m"
    ports              = ["http"]
  }

  env = {
    TZ                            = "UTC"
    TEMPORAL_ADDRESS              = "192.168.68.61:7233"
    TEMPORAL_CORS_ORIGINS         = "http://192.168.68.61:8080"
    TEMPORAL_CSRF_COOKIE_INSECURE = "true"
  }

  service = {
    name     = "temporal-ui"
    port     = "http"
    provider = "consul"
    tags = [
      "temporal",
      "ui",
      "monitoring"
    ]
    checks = [
      {
        name     = "temporal-ui-http"
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "10s"
        check_restart = {
          limit = 3
          grace = "30s"
        }
      }
    ]
  }

  resources = {
    cpu    = 200
    memory = 256
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
