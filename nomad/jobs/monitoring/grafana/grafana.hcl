# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides Grafana dashboards with Prometheus and Loki datasource integration
# via Consul DNS. Runs outside Connect mesh for Traefik accessibility while
# backend services (Prometheus, Loki, Alertmanager) remain in mesh.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "grafana"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Grafana dashboards with Prometheus and Loki via Consul DNS"

# -----------------------------------------------------------------------
# Vault Integration
# -----------------------------------------------------------------------

vault_role = "nomad-workloads"

# -----------------------------------------------------------------------
# Deployment Strategy
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "tier1"
category           = "monitoring"

# -----------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------

network_preset = "bridge"

ports = [
  {
    name = "web"
    to   = 3000
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# -----------------------------------------------------------------------
# Restart & Reschedule Policies
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "fail"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# External Configuration Files
# -----------------------------------------------------------------------

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/grafana/files"
}

external_templates = [
  #{
  #  destination = "local/grafana-provisioning/datasources/ds.yml"
  #  source_file = "datasources.yml"
  #  env         = false
  #  perms       = "0644"
  #  change_mode = "restart"
  #},
  {
    destination = "secrets/grafana.env"
    source_file = "grafana.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

# -----------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------

task = {
  name   = "grafana"
  driver = "docker"
  user   = "root"

  config = {
    image              = "grafana/grafana:12.2.0"
    ports              = ["web"]
    image_pull_timeout = "10m"
    volumes = [
      "local/grafana-provisioning:/etc/grafana/provisioning",
      "/mnt/gdrive/munchbox-data/grafana:/var/lib/grafana"
    ]
  }

  env = {
    GF_SERVER_SERVE_FROM_SUB_PATH = "false"
    GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
  }
}

# -----------------------------------------------------------------------
# Consul Connect
#
# Grafana runs OUTSIDE the mesh to allow Traefik access via bridge
# networking. It connects to Prometheus and Loki via Consul DNS.
# -----------------------------------------------------------------------

consul_connect_enabled = false

# -----------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 3000
standard_http_check_enabled  = true
standard_http_check_path     = "/api/health"

additional_tags = [
  "monitoring",
  "grafana"
]

# -----------------------------------------------------------------------
# Traefik Routing
# -----------------------------------------------------------------------

traefik_enabled     = true
traefik_host        = "grafana.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
