# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization Service
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "grafana"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Grafana dashboards - datasources added manually via UI"

vault_role = "nomad-workloads"

deployment_profile = "canary"
meta_profile       = "tier1"
category           = "monitoring"

resource_tier = "small"

network_preset = "host"

ports = [
  {
    name   = "web"
    static = 3000
  }
]

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "fail"

reschedule_preset = "standard"

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/grafana/files"
}

external_templates = [
  {
    destination = "secrets/grafana.env"
    source_file = "grafana.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

task = {
  name   = "grafana"
  driver = "docker"
  user   = "root"

  config = {
    image              = "grafana/grafana:12.2.0"
    network_mode       = "host"
    ports              = ["web"]
    image_pull_timeout = "10m"
    volumes = [
      "/mnt/gdrive/munchbox-data/grafana:/var/lib/grafana"
    ]
  }

  env = {
    GF_SERVER_SERVE_FROM_SUB_PATH = "false"
    GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
  }
}

consul_connect_enabled = false

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 3000
standard_http_check_enabled  = true
standard_http_check_path     = "/api/health"

additional_tags = [
  "monitoring",
  "grafana"
]

traefik_enabled     = true
traefik_host        = "grafana.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

kill_timeout = "30s"
kill_signal  = "SIGTERM"
