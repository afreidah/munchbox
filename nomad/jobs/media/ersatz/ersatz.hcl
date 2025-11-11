# -------------------------------------------------------------------------------
# ErsatzTV — Virtual TV Channel Engine with Emby Integration
#
# Project: Munchbox
# Author: Alex Freidah
#
# Creates virtual TV channels from Emby library (TV + Movies). Generates
# scheduled broadcasts with guide data and streaming interface. Runs on mccoy
# node with access to media libraries. Exposes web UI/API on :8409 for channel
# management and stream playback configuration.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "ersatztv"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "ErsatzTV virtual TV channel engine with Emby backend"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "media"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "medium"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "ui"
    static = 8409
    port   = 8409
  }
]

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
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "ersatztv"
  driver = "docker"

  config = {
    image              = "jasongdove/ersatztv:latest"
    image_pull_timeout = "10m"
    network_mode       = "host"
    ports              = ["ui"]
    volumes = [
      "/opt/nomad/data/ersatztv/config:/config",
      "/opt/nomad/data/ersatztv/transcode:/transcode",
      "/mnt/gdrive/media/Movies:/media/Movies:ro",
      "/mnt/gdrive/media/TV:/media/TV:ro"
    ]
  }

  env = {
    TZ = "UTC"
  }

  services = [
    {
      name     = "ersatztv"
      port     = "ui"
      provider = "consul"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.ersatztv.rule=Host(`ersatz.munchbox`)",
        "traefik.http.routers.ersatztv.entrypoints=websecure",
        "traefik.http.routers.ersatztv.tls=true",
        "traefik.http.routers.ersatztv.middlewares=dashboard-allowlan@file",
        "traefik.http.services.ersatztv.loadbalancer.server.port=8409",
        "media",
        "ersatztv",
        "streaming"
      ]
      checks = [
        {
          name     = "ersatztv-ui"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      ]
    }
  ]

  resources = {
    cpu    = 500
    memory = 1024
  }

  kill_timeout = "30s"
  kill_signal  = "SIGTERM"
}

# -----------------------------------------------------------------------
# Log Configuration
# -----------------------------------------------------------------------

log_max_files     = 5
log_max_file_size = 20

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  tiny = {
    cpu            = 150
    memory         = 128
    ephemeral_disk = 200
  }
  small = {
    cpu            = 300
    memory         = 256
    ephemeral_disk = 500
  }
  medium = {
    cpu            = 500
    memory         = 1024
    ephemeral_disk = 1000
  }
  large = {
    cpu            = 2000
    memory         = 4096
    ephemeral_disk = 2000
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  bridge = {
    mode = "bridge"
  }
  host = {
    mode = "host"
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
    auto_promote      = false
    canary            = 0
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier2 = {
    tier = "important"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    delay           = "5s"
    delay_function  = "exponential"
    max_reschedules = 3
    unlimited       = false
  }
}
