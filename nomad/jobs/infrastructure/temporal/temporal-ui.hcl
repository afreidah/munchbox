# -------------------------------------------------------------------------------
# Temporal — Web UI
#
# Project: Munchbox
# Author: Alex Freidah
#
# Temporal web UI for workflow monitoring and management. Connects to
# Temporal server gRPC API on port 7233. Service discovery via Consul.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "temporal-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
priority        = 50

job_description = "Temporal UI — workflow monitoring and management console"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }
]

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier-2"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "http"
    static = 8080
    port   = 8080
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "ui"
  driver = "docker"

  config = {
    image              = "temporalio/ui:2.31.1"
    image_pull_timeout = "10m"
    network_mode       = "host"
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

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  small = {
    cpu             = 200
    memory          = 256
    ephemeral_disk  = 500
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "checks"
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
  tier-2 = {
    tier = "tier-2"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    max_reschedules = 3
    delay           = "5s"
    delay_function  = "exponential"
    unlimited       = false
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  host = {
    mode = "host"
  }
}
