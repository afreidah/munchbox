# -------------------------------------------------------------------------------
# Alertmanager — Alert Routing and Notification System
#
# Project: Munchbox / Author: Alex Freidah
#
# Handles alerts from Prometheus with deduplication, grouping, and routing to
# notification channels. Integrated with Consul Connect mesh for secure alert
# ingestion from Prometheus.
# -------------------------------------------------------------------------------

job_name        = "alertmanager"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "utility"
namespace       = "default"
priority        = 50
job_description = "Alertmanager for Prometheus alerts with Connect mesh"

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "monitoring"

resource_tier  = "small"
network_preset = "bridge"

ports = [
  {
    name = "http"
    to   = 9093
  },
  {
    name = "cluster"
    to   = 9094
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

vault_role = "nomad-workloads"

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
    change_mode     = "restart"
    left_delimiter  = "[["
    right_delimiter = "]]"
  }
]

task = {
  name   = "alertmanager"
  driver = "docker"

  config = {
    image              = "prom/alertmanager:v0.27.0"
    ports              = ["http", "cluster"]
    image_pull_timeout = "10m"

    args = [
      "--config.file=/etc/alertmanager/config/alertmanager.yml",
      "--storage.path=/alertmanager",
      "--web.listen-address=0.0.0.0:9093",
      "--cluster.listen-address=0.0.0.0:9094",
      "--web.external-url=https://alertmanager.munchbox"
    ]

    volumes = [
      "local/config:/etc/alertmanager/config:ro"
    ]
  }

  env = {
    TZ = "America/Los_Angeles"
  }

  resources = {
    tier = "small"
  }
}

# -----------------------------------------------------------------------------
# Consul Connect
# -----------------------------------------------------------------------------

consul_connect_enabled = false

# -----------------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------------

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 9093
standard_http_check_enabled  = true
standard_http_check_path     = "/-/ready"

additional_tags = [
  "monitoring",
  "alertmanager",
  "alerts"
]

# -----------------------------------------------------------------------------
# Traefik Routing
# -----------------------------------------------------------------------------

traefik_enabled         = true
traefik_host            = "alertmanager.munchbox"
traefik_entrypoints     = "websecure"
traefik_tls_enabled     = true
traefik_middlewares     = "dashboard-allowlan@file"

# -----------------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
