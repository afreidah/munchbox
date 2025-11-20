# -------------------------------------------------------------------------------
# Blackbox Exporter — Network Probe and Endpoint Monitoring
#
# Project: Munchbox / Author: Alex Freidah
#
# Probes HTTP, HTTPS, DNS, TCP, and ICMP endpoints to verify availability and
# response times. Uses host networking for direct network access. Scraped by
# Prometheus via Consul service discovery.
# -------------------------------------------------------------------------------

job_name        = "blackbox-exporter"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "utility"
namespace       = "default"
priority        = 50
job_description = "Blackbox Exporter - network probing and endpoint monitoring"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "monitoring"

resource_tier  = "tiny"
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9115
  }
]

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
  base_path = "jobs/monitoring/blackbox-exporter/files"
}

external_templates = [
  {
    destination     = "local/config/blackbox.yml"
    source_file     = "blackbox.yml"
    env             = false
    perms           = "0644"
    change_mode     = "restart"
    left_delimiter  = "[["
    right_delimiter = "]]"
  }
]

task = {
  name   = "blackbox-exporter"
  driver = "docker"

  config = {
    image        = "prom/blackbox-exporter:v0.25.0"
    network_mode = "host"
    ports        = ["http"]
    args = [
      "--config.file=/etc/blackbox/config/blackbox.yml",
      "--web.listen-address=0.0.0.0:9115"
    ]
    volumes = [
      "local/config:/etc/blackbox/config:ro"
    ]
  }

  env = {
    TZ = "America/Los_Angeles"
  }

  resources = {
    cpu    = 100
    memory = 64
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
standard_service_port_number = 9115
standard_http_check_enabled  = true
standard_http_check_path     = "/health"

additional_tags = [
  "monitoring",
  "blackbox-exporter",
  "probes",
  "network-monitoring"
]

# -----------------------------------------------------------------------------
# Traefik Routing
# -----------------------------------------------------------------------------

traefik_enabled = false

# -----------------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
