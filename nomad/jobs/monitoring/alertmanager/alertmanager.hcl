# -------------------------------------------------------------------------------
# Alertmanager — Alert Routing and Notification Service with Telegram
#
# Project: Munchbox / Author: Alex Freidah
#
# Receives alerts from Prometheus, groups and routes them according to rules,
# manages silences and inhibition, and sends formatted notifications via Telegram
# bot integration. Provides web UI with LAN-only access via Traefik routing.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "alertmanager"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Alertmanager with Telegram notification routing"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier1"
category           = "monitoring"

# --- Resource allocation ---
resource_tier = "tiny"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "web"
    static = 9093
  }
]

# --- Restart policy ---
restart_attempts = 5
restart_interval = "10m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
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

# --- Task definition ---
task = {
  name   = "alertmanager"
  driver = "docker"

  config = {
    image = "quay.io/prometheus/alertmanager:v0.28.1"
    ports = ["web"]
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

  resources = {
    tier = "tiny"
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 9093
standard_http_check_enabled  = true
standard_http_check_path     = "/-/ready"
additional_tags              = ["monitoring", "alertmanager", "notifications", "telegram"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  tiny = {
    cpu            = 150
    memory         = 128
    ephemeral_disk = 200
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
