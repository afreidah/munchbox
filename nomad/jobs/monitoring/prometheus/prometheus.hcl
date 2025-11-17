# -------------------------------------------------------------------------------
# Prometheus — Metrics Collection with Alert Rules and Dynamic Discovery
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "prometheus"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Prometheus metrics collection with alerting"

deployment_profile = "standard"
meta_profile       = "tier1"
category           = "monitoring"

resource_tier  = "medium"
network_preset = "host"  # Changed to host

ports = [
  {
    name   = "web"
    static = 9090  # Changed to static for host networking
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

volume = {
  name       = "prometheus-data"
  type       = "host"
  source     = "prometheus-data"
  mount_path = "/opt/nomad/data/prometheus-data"
  read_only  = false
}

vault_role = "nomad-workloads"

external_files = {
  enabled   = true
  base_path = "jobs/monitoring/prometheus/files"
}

external_templates = [
  {
    destination     = "local/config/prometheus.yml"
    source_file     = "prometheus.yml"
    env             = false
    perms           = "0644"
    change_mode     = "restart"
    left_delimiter  = "[["
    right_delimiter = "]]"
  },
  {
    destination     = "local/config/alert_rules.yml"
    source_file     = "alert_rules.yml"
    env             = false
    perms           = "0644"
    change_mode     = "signal"
    change_signal   = "SIGHUP"
    left_delimiter  = "[["
    right_delimiter = "]]"
  },
  {
    destination     = "local/secrets/consul_token"
    source_file     = "consul_token.tpl"
    env             = false
    perms           = "0600"
    change_mode     = "restart"
    left_delimiter  = "[["
    right_delimiter = "]]"
  },
  {
    destination     = "local/secrets/vault_token"
    source_file     = "vault_token.tpl"
    env             = false
    perms           = "0600"
    change_mode     = "restart"
    left_delimiter  = "[["
    right_delimiter = "]]"
  }
]

task = {
  name   = "prometheus"
  driver = "docker"
  user   = "root"

  config = {
    image              = "prom/prometheus:v2.54.1"
    ports              = ["web"]
    image_pull_timeout = "10m"

    args = [
      "--config.file=/etc/prometheus/config/prometheus.yml",
      "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
      "--web.listen-address=0.0.0.0:9090",
      "--web.enable-lifecycle",
      "--web.enable-admin-api",
      "--storage.tsdb.retention.time=30d",
      "--storage.tsdb.wal-compression",
      "--web.page-title=Munchbox Prometheus",
    ]

    volumes = [
      "local/config:/etc/prometheus/config:ro",
      "local/secrets:/etc/prometheus/secrets:ro",
    ]
  }

  env = {
    TZ                              = "America/Los_Angeles"
    CONSUL_HTTP_ADDR                = "127.0.0.1:8500"
    PROMETHEUS_WEB_ENABLE_LIFECYCLE = "true"
    PROMETHEUS_WEB_ENABLE_ADMIN_API = "true"
  }

  resources = {
    tier = "medium"
  }
}

consul_connect_enabled = false  # Disabled for Prometheus - needs direct network access

standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 9090
standard_http_check_enabled  = true
standard_http_check_path     = "/-/ready"

additional_tags = [
  "monitoring",
  "prometheus",
  "metrics"
]

kill_timeout = "60s"
kill_signal  = "SIGTERM"
