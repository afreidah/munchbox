# -------------------------------------------------------------------------------
# Alertmanager — Alert Routing and Notification Service with Telegram
#
# Project: Munchbox / Author: Alex Freidah
#
# Receives alerts from Prometheus, groups and routes them according to rules,
# manages silences and inhibition, and sends formatted notifications via Telegram
# bot integration. Provides web UI with LAN-only access via Traefik routing.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "alertmanager"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Alertmanager with Telegram notification routing"

# -----------------------------------------------------------------------
# Deployment Strategy
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "monitoring"

# -----------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------

resource_tier = "tiny"

# -----------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------

network_preset = "bridge"

ports = [
  {
    name = "web"
    to   = 9093
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule Policies
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "15s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# External Configuration Files
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
# Task Definition
# -----------------------------------------------------------------------

task = {
  name   = "alertmanager"
  driver = "docker"

  config = {
    image = "quay.io/prometheus/alertmanager:v0.29.0"
    ports = ["web"]
    args = [
      "--config.file=/etc/alertmanager/alertmanager.yml",
      "--web.listen-address=0.0.0.0:9093",
      "--web.external-url=https://alertmanager.munchbox/",
      "--cluster.listen-address="
    ]
    volumes = [
      "local/config:/etc/alertmanager:ro",
      "/mnt/gdrive/munchbox-data/alertmanager:/alertmanager"
    ]
  }

  env = {
    TZ                                  = "America/Los_Angeles"
    ALERTMANAGER_WEB_EXTERNAL_URL       = "https://alertmanager.munchbox/"
    ALERTMANAGER_CLUSTER_LISTEN_ADDRESS = ""
  }
}

# -----------------------------------------------------------------------
# Consul Connect
# -----------------------------------------------------------------------

consul_connect_enabled = true

# -----------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 9093
standard_http_check_enabled  = true
standard_http_check_path     = "/-/ready"
additional_tags              = ["monitoring", "alertmanager", "notifications", "telegram"]

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
