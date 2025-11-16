# -------------------------------------------------------------------------------
# Docker Registry UI — Web Interface for Registry Mirror
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides a user-friendly web UI for browsing and managing Docker images
# in the private registry. Authenticates via basic auth and proxies to registry.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "registry-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Docker registry web UI — browse and manage images in private registry"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "bridge"

ports = [
  {
    name = "http"
    to   = 5001
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

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "registry-ui"
  driver = "docker"

  config = {
    image = "joxit/docker-registry-ui:latest"
    ports = ["http"]
  }

  env = {
    REGISTRY_URL        = "http://goren:5000"
    REGISTRY_TITLE      = "Docker Registry Mirror"
    DELETE_IMAGES       = "false"
    REGISTRY_BASIC_AUTH = "true"
    REGISTRY_USERNAME   = "alex.freidah"
    REGISTRY_PASSWORD   = "changeme"
    TZ                  = "UTC"
  }

  service = {
    name     = "docker-registry-ui"
    port     = "http"
    provider = "consul"
    tags = [
      "registry-ui",
      "docker",
      "ui"
    ]
  }

  resources = {
    cpu    = 150
    memory = 128
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
