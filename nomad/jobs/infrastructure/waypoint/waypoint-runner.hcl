# -------------------------------------------------------------------------------
# Waypoint Runner — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Waypoint runner deployment that connects to server via TLS with token auth.
# Reads bootstrap token from waypoint-data volume (shared with server).
# Mounts Docker socket for build operations.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "waypoint-runner"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
priority        = 50

job_description = "Waypoint runner — connects to server with TLS token auth, Docker socket mounted"

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

# -----------------------------------------------------------------------
# Storage & Volumes
# -----------------------------------------------------------------------

volume = {
  name       = "waypoint-data"
  type       = "host"
  source     = "waypoint-data"
  read_only  = true
  mount_path = "/data"
}

# -----------------------------------------------------------------------
# Additional Volumes
# -----------------------------------------------------------------------

volume_mounts = [
  {
    volume      = "docker-socket"
    destination = "/var/run/docker.sock"
    read_only   = false
  }
]

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
  name   = "runner"
  driver = "docker"

  config = {
    image        = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
    network_mode = "host"
    entrypoint   = ["/bin/sh", "-c"]
    args = [
      "export WAYPOINT_SERVER_TOKEN=$(cat /data/waypoint-token) && exec waypoint runner agent"
    ]
  }

  env = {
    TZ                              = "UTC"
    WAYPOINT_SERVER_ADDR            = "mccoy:9701"
    WAYPOINT_SERVER_TLS             = "1"
    WAYPOINT_SERVER_TLS_SKIP_VERIFY = "1"
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
