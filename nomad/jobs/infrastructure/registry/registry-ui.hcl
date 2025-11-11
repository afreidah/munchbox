# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Docker Registry UI — Web Interface for Registry Mirror
#
# Provides a user-friendly web UI for browsing and managing Docker images
# in the private registry. Authenticates via basic auth and proxies to registry.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "registry-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
priority        = 50

job_description = "Docker registry web UI — browse and manage images in private registry"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "standard"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "bridge"

ports = [
  {
    name   = "http"
    static = 5001
    port   = 5001
  }
]

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "goren"
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

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

  kill_timeout = "30s"
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  small = {
    cpu             = 150
    memory          = 128
    ephemeral_disk  = 300
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  standard = {
    tier = "infrastructure"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    max_reschedules = 3
    delay           = "15s"
    delay_function  = "exponential"
    unlimited       = false
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  bridge = {
    mode = "bridge"
  }
}
