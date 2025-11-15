# -------------------------------------------------------------------------------
# Emby Media Server — Streaming Platform with Hardware Transcoding Support
#
# Project: Munchbox / Author: Alex Freidah
#
# Media streaming server running on mccoy node with direct host volume binds
# for config, cache, and media libraries. Supports hardware transcoding via
# Intel/AMD iGPU. Exposes web UI on :8096 (HTTP) and :8920 (HTTPS). Media
# sourced from mounted /mnt/gdrive with read-only access per library type.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "emby"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Emby media server with GPU transcoding and library management"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier1"
category           = "media"

# --- Resource allocation ---
resource_tier = "large"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "web"
    static = 8096
  },
  {
    name   = "https"
    static = 8920
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "emby"
  driver = "docker"

  config = {
    image              = "linuxserver/emby:latest"
    image_pull_timeout = "10m"
    ports              = ["web", "https"]
    devices = [
      {
        host_path          = "/dev/dri"
        container_path     = "/dev/dri"
        cgroup_permissions = "rwm"
      }
    ]
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
  }

  env = {
    PUID = "1001"
    PGID = "1001"
    TZ   = "UTC"
  }

  resources = {
    cpu    = 2000
    memory = 4096
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 8096
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags              = ["media", "emby", "streaming"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  large = {
    cpu            = 2000
    memory         = 4096
    ephemeral_disk = 2000
  }
}

# --- Network presets ---
network_presets = {
  host = {
    mode = "host"
  }
}

# --- Deployment profiles ---
deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }
}

# --- Meta profiles ---
meta_profiles = {
  tier1 = {
    tier = "critical"
  }
}

# --- Reschedule presets ---
reschedule_presets = {
  standard = {
    delay           = "5s"
    delay_function  = "exponential"
    max_reschedules = 3
    unlimited       = false
  }
}
