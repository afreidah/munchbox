# -------------------------------------------------------------------------------
# Deluge — BitTorrent Client with VPN Integration and Web UI
#
# Project: Munchbox
# Author: Alex Freidah
#
# BitTorrent client running on mccoy node with all traffic routed through
# WireGuard VPN via policy-based marking. Persists configuration and downloads
# on host volumes. Exposes web UI on :8112 for torrent management. Pulls
# credentials from Vault for daemon auth and web password.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "deluge"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Deluge BitTorrent client with VPN policy routing"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "utility"

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
    name   = "web"
    static = 8112
    port   = 8112
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
# Storage Configuration
# -----------------------------------------------------------------------

volume = {
  name       = "deluge-data"
  type       = "host"
  source     = "deluge-data"
  mount_path = "/config"
  read_only  = false
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
# Vault Integration
# -----------------------------------------------------------------------

vault = {
  enabled = true
  role    = "nomad-workloads"
  aud     = ["vault.io"]
}

# -----------------------------------------------------------------------
# External File Configuration
# -----------------------------------------------------------------------

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
    change_signal   = ""
    left_delimiter  = "{{{"  # Add this
    right_delimiter = "}}}"  # Add this
  }
]

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

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

  templates = [
    {
      destination = "local/auth"
      perms       = "0600"
      env         = false
      change_mode = "restart"
      data        = <<-EOH
{{ with secret "kv/data/deluge" }}
localclient:{{ .Data.data.password }}:10
{{ end }}
EOH
    },
    {
      destination = "secrets/deluge.env"
      perms       = "0600"
      env         = true
      change_mode = "restart"
      data        = <<-EOENV
{{ with secret "kv/data/deluge" -}}
DELUGE_WEB_PASSWORD={{ .Data.data.web_password }}
{{- end }}
EOENV
    }
  ]

  services = [
    {
      name     = "deluge"
      port     = "web"
      provider = "consul"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.deluge.rule=Host(`deluge.munchbox`)",
        "traefik.http.routers.deluge.entrypoints=websecure",
        "traefik.http.routers.deluge.tls=true",
        "traefik.http.routers.deluge.middlewares=dashboard-allowlan@file",
        "traefik.http.services.deluge.loadbalancer.server.port=8112",
        "torrent",
        "deluge",
        "downloads"
      ]
      checks = [
        {
          name     = "deluge-web"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      ]
    }
  ]

  resources = {
    cpu    = 300
    memory = 256
  }
}

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
    healthy_deadline  = "3m"
    progress_deadline = "5m"
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
