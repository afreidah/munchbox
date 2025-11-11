# -------------------------------------------------------------------------------
# Waypoint Server — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Waypoint server deployment with local persistence, host networking, and
# dual gRPC and UI service registration.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "waypoint-server"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
priority        = 50

job_description = "Waypoint server (local dev, no auth) — gRPC and UI services"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "tier-2"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "standard"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "grpc"
    static = 9701
    port   = 9701
  },
  {
    name   = "ui"
    static = 9702
    port   = 9702
  }
]

# -----------------------------------------------------------------------
# Storage & Volumes
# -----------------------------------------------------------------------

volume = {
  name       = "waypoint-data"
  type       = "host"
  source     = "waypoint-data"
  read_only  = false
  mount_path = "/var/lib/waypoint"
}

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "30s"
restart_delay    = "5s"
restart_mode     = "delay"

reschedule_preset = "aggressive"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "server"
  driver = "docker"

  config = {
    image        = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
    network_mode = "host"
    entrypoint   = ["/bin/sh", "-lc"]
    args = [
      "mkdir -p /var/lib/waypoint && exec waypoint server run -accept-tos -db=/var/lib/waypoint/waypoint.db -listen-grpc=0.0.0.0:9701 -listen-http=0.0.0.0:9702"
    ]
    ports = ["grpc", "ui"]
  }

  resources = {
    cpu    = 300
    memory = 256
  }

  restart = {
    attempts = 3
    interval = "30s"
    delay    = "5s"
    mode     = "delay"
  }

  services = [
    {
      name     = "waypoint-grpc"
      port     = "grpc"
      provider = "consul"
      tags     = ["waypoint", "grpc"]
    },
    {
      name     = "waypoint-ui"
      port     = "ui"
      provider = "consul"
      tags     = ["waypoint", "ui"]
    }
  ]
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  standard = {
    cpu             = 300
    memory          = 256
    ephemeral_disk  = 500
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  canary = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
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
  aggressive = {
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
