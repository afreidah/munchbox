# -------------------------------------------------------------------------------
# Blackbox Exporter — Internal Endpoint Monitoring and Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs blackbox exporter on static host port 9115 with host networking for
# Prometheus probe execution. Uses Consul service registration with LAN IP
# binding. Probes internal services and endpoints.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "blackbox-exporter"
job_type        = "service"
job_description = "Blackbox exporter — internal endpoint monitoring and metrics collection"

# --- Deployment and metadata ---
deployment_profile = "canary"
meta_profile       = "tier2"
category           = "monitoring"

# --- Resource allocation ---
resource_tier = "tiny"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9115
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

# --- Restart policy ---
restart_attempts = 5
restart_interval = "10m"
restart_delay    = "5s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "extended"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/monitoring/blackbox-exporter/files"
}

external_templates = [
  {
    destination   = "local/blackbox.yml"
    source_file   = "blackbox.yml"
    env           = false
    perms         = "0644"
    change_mode   = "signal"
    change_signal = "SIGHUP"
  }
]

# --- Task definition ---
task = {
  name   = "exporter"
  driver = "docker"

  config = {
    image = "prom/blackbox-exporter:v0.25.0"
    ports = ["http"]
    args = [
      "--config.file=/local/blackbox.yml"
    ]
  }

  resources = {
    cpu    = 50
    memory = 64
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 9115
standard_http_check_enabled  = true
standard_http_check_path     = "/metrics"
additional_tags              = ["metrics", "prometheus"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
