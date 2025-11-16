# -------------------------------------------------------------------------------
# Docker Registry — Private Container Image Repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Private Docker registry for Munchbox cluster. Stores images locally with
# proper CORS headers for multi-host access.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "registry"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
node_pool       = "core"
priority        = 50
job_description = "Private Docker registry with CORS support"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "registry"
    static = 5000
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "goren"
  }
]

# --- Persistent storage volume ---
volume = {
  name       = "registry-data"
  type       = "host"
  source     = "registry-data"
  mount_path = "/var/lib/registry"
  read_only  = false
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/registry/files"
}

external_templates = [
  {
    destination = "local/config/config.yml"
    source_file = "config.yml"
    env         = false
    perms       = "0644"
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "registry"
  driver = "docker"

  config = {
    image = "registry:2"
    ports = ["registry"]
    volumes = [
      "local/config:/etc/docker/registry"
    ]
  }

  env = {
    TZ = "UTC"
  }

  service = {
    name     = "docker-mirror"
    port     = "registry"
    provider = "consul"
    tags     = ["registry", "docker"]
    checks = [
      {
        name     = "registry-http"
        type     = "http"
        path     = "/v2/"
        interval = "10s"
        timeout  = "3s"
        check_restart = {
          limit = 3
          grace = "10s"
        }
      }
    ]
  }

  resources = {
    cpu    = 250
    memory = 256
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
