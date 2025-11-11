# -------------------------------------------------------------------------------
# Docker Registry — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Private Docker registry for Munchbox cluster. Stores images locally with
# proper CORS headers for multi-host access.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "registry"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
priority        = 50

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
    name   = "registry"
    static = 5000
    port   = 5000
  }
]

# -----------------------------------------------------------------------
# Storage & Volumes
# -----------------------------------------------------------------------

volume = {
  name       = "registry-data"
  type       = "host"
  source     = "registry-data"
  read_only  = false
  mount_path = "/var/lib/registry"
}

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
  name   = "registry"
  driver = "docker"

  config = {
    image = "registry:2"
    ports = ["registry"]
  }

  env = {
    TZ = "UTC"
  }

  templates = [
    {
      destination = "local/config/config.yml"
      perms       = "0644"
      change_mode = "restart"
      data        = <<-EOF
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ["http://192.168.68.60:5001", "http://registry.munchbox"]
    Access-Control-Allow-Methods: ["GET", "HEAD", "OPTIONS"]
    Access-Control-Allow-Headers: ["Authorization", "Accept", "Cache-Control", "Content-Type", "Origin"]
EOF
    }
  ]

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

  restart = {
    attempts = 3
    interval = "5m"
    delay    = "15s"
    mode     = "fail"
  }

  kill_timeout = "30s"
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  small = {
    cpu             = 250
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
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
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
