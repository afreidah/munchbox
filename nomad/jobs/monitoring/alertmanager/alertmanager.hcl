# -------------------------------------------------------------------------------
# Alertmanager — Alert Routing and Notification Service with Telegram
#
# Project: Munchbox
# Author: Alex Freidah
#
# Receives alerts from Prometheus, groups and routes them according to rules,
# manages silences and inhibition, and sends formatted notifications via Telegram
# bot integration. Provides web UI with LAN-only access via Traefik routing.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "alertmanager"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Alertmanager with Telegram notification routing"

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "monitoring"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "tiny"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "web"
    static = 9093
    port   = 9093
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# External File Configuration
# -----------------------------------------------------------------------

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/alertmanager/files"
}

external_templates = [
  {
    destination     = "local/config/alertmanager.yml"
    source_file     = "alertmanager.yml"
    env             = false
    perms           = "0644"
    change_mode     = "signal"
    change_signal   = "SIGHUP"
    left_delimiter  = "[["
    right_delimiter = "]]"
  }
]

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "alertmanager"
  driver = "docker"

  config = {
    image        = "quay.io/prometheus/alertmanager:v0.28.1"
    network_mode = "host"
    ports        = ["web"]
    args = [
      "--config.file=/etc/alertmanager/alertmanager.yml",
      "--web.listen-address=0.0.0.0:9093",
      "--web.external-url=https://alertmanager.munchbox/",
      "--cluster.listen-address="
    ]
    volumes = [
      "local/config:/etc/alertmanager:ro"
    ]
  }

  env = {
    TZ                                  = "America/Los_Angeles"
    ALERTMANAGER_WEB_EXTERNAL_URL       = "https://alertmanager.munchbox/"
    ALERTMANAGER_CLUSTER_LISTEN_ADDRESS = ""
  }

  services = [
    {
      name     = "alertmanager"
      port     = "web"
      provider = "consul"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.alertmanager.rule=Host(`alertmanager.munchbox`)",
        "traefik.http.routers.alertmanager.entrypoints=websecure",
        "traefik.http.routers.alertmanager.tls=true",
        "traefik.http.routers.alertmanager.middlewares=dashboard-allowlan@file",
        "traefik.http.services.alertmanager.loadbalancer.server.port=9093",
        "traefik.http.services.alertmanager.loadbalancer.server.scheme=http",
        "traefik.http.services.alertmanager.loadbalancer.healthcheck.path=/-/ready",
        "traefik.http.services.alertmanager.loadbalancer.healthcheck.interval=30s",
        "traefik.http.services.alertmanager.loadbalancer.healthcheck.timeout=5s",
        "monitoring",
        "alertmanager",
        "notifications",
        "telegram"
      ]
      checks = [
        {
          name     = "am-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "3s"
        },
        {
          name     = "am-healthy"
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "5s"
        }
      ]
    }
  ]

  resources = {
    tier = "tiny"
  }

  kill_timeout   = "30s"
  kill_signal    = "SIGTERM"
  shutdown_delay = "15s"
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
    cpu            = 250
    memory         = 512
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
