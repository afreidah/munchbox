# -------------------------------------------------------------------------------
# Loki — Centralized Log Aggregation
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "loki"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
node_pool       = "edge"
priority        = 50
job_description = "Loki centralized log aggregation with 5-day retention"

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "logging"

resource_tier  = "medium"
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 3100
  },
  {
    name   = "grpc"
    static = 9096
  }
]

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

volume = {
  name       = "loki-data"
  type       = "host"
  source     = "loki-data"
  read_only  = false
  mount_path = "/loki"
}

external_files = {
  enabled   = true
  base_path = "jobs/logging/loki/files"
}

external_templates = [
  {
    destination = "local/config/config.yaml"
    source_file = "config.yaml"
    perms       = "0644"
    change_mode = "restart"
  }
]

task = {
  name   = "loki"
  driver = "docker"
  config = {
    image = "grafana/loki:3.5.8"
    ports = ["http", "grpc"]
    args = [
      "-config.file=/etc/loki/config.yaml"
    ]
    volumes = [
      "local/config:/etc/loki:ro"
    ]
  }
  env = {
    TZ = "America/Los_Angeles"
  }
  resources = {
    cpu    = 500
    memory = 512
  }
}

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 3100
standard_http_check_enabled  = true
standard_http_check_path     = "/ready"
additional_tags              = ["logging", "loki", "observability"]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
