# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client with VPN Integration and Web UI
#
# Project: Munchbox / Author: Alex Freidah
#
# BitTorrent client running on mccoy node with all traffic routed through
# WireGuard VPN via policy-based marking. Persists configuration and downloads
# on host volumes. Exposes web UI on :8112 for torrent management. Pulls
# credentials from Vault for daemon auth and web password.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "deluge"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Deluge BitTorrent client with VPN policy routing"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "utility"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "web"
    static = 8112
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

# --- Persistent storage volume ---
volume = {
  name       = "deluge-data"
  type       = "host"
  source     = "deluge-data"
  mount_path = "/config"
  read_only  = false
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/media/deluge/files"
}

external_templates = [
  {
    destination     = "local/entrypoint.sh"
    source_file     = "entrypoint.sh"
    env             = false
    perms           = "0755"
    change_mode     = "restart"
    left_delimiter  = "{{{"
    right_delimiter = "}}}"
  },
  {
    destination     = "local/auth"
    source_file     = "auth.tpl"
    env             = false
    perms           = "0600"
    change_mode     = "restart"
  },
  {
    destination     = "secrets/deluge.env"
    source_file     = "deluge.env.tpl"
    env             = true
    perms           = "0600"
    change_mode     = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "deluge"
  driver = "docker"

  identity = {
    env  = true
    file = true
    aud  = ["vault.io"]
  }

  config = {
    image              = "docker-mirror.service.consul:5000/deluge-with-vpnmark:latest"
    image_pull_timeout = "10m"
    ports              = ["web"]
    cap_add            = ["CHOWN", "FOWNER"]
    volumes = [
      "/opt/nomad/data/deluge-data/downloads:/downloads",
      "/mnt/gdrive/nomad_deluge_downloads:/completed"
    ]
    entrypoint = ["/local/entrypoint.sh"]
  }

  env = {
    PUID                       = "1001"
    PGID                       = "1001"
    TZ                         = "UTC"
    DELUGE_MOVE_COMPLETED_PATH = "/completed"
    DELUGE_MOVE_COMPLETED      = "true"
  }

  resources = {
    cpu    = 300
    memory = 256
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 8112
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags              = ["torrent", "deluge", "downloads"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  small = {
    cpu            = 300
    memory         = 256
    ephemeral_disk = 500
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
    healthy_deadline  = "3m"
    progress_deadline = "5m"
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
