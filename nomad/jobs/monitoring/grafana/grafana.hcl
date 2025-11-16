# -------------------------------------------------------------------------------
# Grafana — Monitoring Dashboards and Visualization Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides Grafana dashboards with Prometheus and Loki datasource integration
# via Consul DNS. Provisioned datasources authoritative to prevent drift, and
# Traefik HTTPS routing.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "grafana"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "edge"
namespace       = "default"
priority        = 50
job_description = "Grafana dashboards with Prometheus and Loki integration"

# --- Vault integration ---
vault_role = "nomad-workloads"

# --- Deployment and metadata ---
deployment_profile = "canary"
meta_profile       = "tier1"
category           = "monitoring"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "web"
    static = 3000
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.class}"
    operator  = "="
    value     = "utility"
  }
]

# --- Persistent storage volume ---
volume = {
  name       = "grafana-data"
  type       = "host"
  source     = "grafana-data"
  mount_path = "/var/lib/grafana"
  read_only  = false
}

# --- Restart policy ---
restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/monitoring/grafana/files"
}

external_templates = [
  {
    destination = "local/grafana-provisioning/datasources/ds.yml"
    source_file = "datasources.yml"
    env         = false
    perms       = "0644"
    change_mode = "restart"
  },
  {
    destination = "secrets/grafana.env"
    source_file = "grafana.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "grafana"
  driver = "docker"
  user   = "root"

  config = {
    image              = "grafana/grafana:12.2.0"
    ports              = ["web"]
    image_pull_timeout = "10m"
    dns_search_domains = ["service.consul"]
    dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
    volumes = [
      "local/grafana-provisioning:/etc/grafana/provisioning"
    ]
  }

  env = {
    GF_SERVER_SERVE_FROM_SUB_PATH = "false"
    GF_SERVER_ROOT_URL            = "https://grafana.munchbox/"
    NO_PROXY                      = "localhost,127.0.0.1,*.service.consul,service.consul,192.168.68.0/24"
  }

  resources = {
    tier = "small"
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "web"
standard_service_port_number = 3000
standard_http_check_enabled  = true
standard_http_check_path     = "/api/health"
additional_tags              = ["monitoring", "grafana"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
