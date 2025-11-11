# -------------------------------------------------------------------------------
# Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
# Project: Munchbox
# Author: Alex Freidah
#
# Media streaming server running on mccoy node with direct host volume binds
# for config, cache, and media libraries. Supports hardware transcoding via
# Intel/AMD iGPU. Exposes web UI on :8096 (HTTP) and :8920 (HTTPS). Media
# sourced from mounted /mnt/gdrive with read-only access per library type.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "emby"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Emby media server with GPU transcoding and library management"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "media"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "large"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "web"
    static = 8096
    port   = 8096
  },
  {
    name   = "https"
    static = 8920
    port   = 8920
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
  name   = "emby"
  driver = "docker"

  config = {
    image              = "linuxserver/emby:latest"
    image_pull_timeout = "10m"
    network_mode       = "host"
    ports              = ["web", "https"]
    volumes = [
      "/opt/nomad/data/emby/config:/config",
      "/opt/nomad/data/emby/cache:/cache",
      "/opt/nomad/data/emby/transcode:/transcode",
      "/mnt/gdrive/media/Movies:/media/Movies:ro",
      "/mnt/gdrive/media/TV:/media/TV:ro",
      "/mnt/gdrive/media/Music:/media/Music:ro",
      "/mnt/gdrive/media/Books:/media/Books:ro",
      "/mnt/gdrive/media/ISOs:/media/ISOs:ro",
      "/mnt/gdrive/media/Software:/media/Software:ro",
      "/mnt/gdrive/media/hacker-magazines:/media/hacker-magazines:ro",
      "/mnt/gdrive/media/random:/media/random:ro",
      "/mnt/gdrive/media/taxes:/media/taxes:ro"
    ]
    devices = [
      {
        host_path          = "/dev/dri"
        container_path     = "/dev/dri"
        cgroup_permissions = "rwm"
      }
    ]
  }

  env = {
    PUID = "1001"
    PGID = "1001"
    TZ   = "UTC"
  }

  services = [
    {
      name     = "emby"
      port     = "web"
      provider = "consul"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.emby.rule=Host(`emby.munchbox`)",
        "traefik.http.routers.emby.entrypoints=websecure",
        "traefik.http.routers.emby.tls=true",
        "traefik.http.routers.emby.middlewares=dashboard-allowlan@file",
        "traefik.http.services.emby.loadbalancer.server.port=8096",
        "media",
        "emby",
        "streaming"
      ]
      checks = [
        {
          name     = "emby-web"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      ]
    }
  ]

  resources = {
    cpu        = 2000
    memory     = 4096
    memory_max = 6144
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
  tier1 = {
    tier = "critical"
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
