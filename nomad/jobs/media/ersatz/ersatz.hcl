# -------------------------------------------------------------------------------
# ErsatzTV — Virtual TV Channel Engine with Emby Integration
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates virtual TV channels from Emby library (TV + Movies). Generates
# scheduled broadcasts with guide data and streaming interface. Runs on mccoy
# node with access to media libraries. Exposes web UI/API on :8409 for channel
# management and stream playback configuration.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "ersatztv"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "ErsatzTV virtual TV channel engine with Emby backend"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "media"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "ui"
    static = 8409
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
  name   = "ersatztv"
  driver = "docker"

  config = {
    image              = "jasongdove/ersatztv:latest"
    image_pull_timeout = "10m"
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

  resources = {
    cpu    = 500
    memory = 1024
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "ui"
standard_service_port_number = 8409
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags              = ["media", "ersatztv", "streaming"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  medium = {
    cpu            = 500
    memory         = 1024
    ephemeral_disk = 1000
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
  tier2 = {
    tier = "important"
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
