# jobs/logging/loki/loki.hcl
# -------------------------------------------------------------------------------
# Loki — Centralized Log Aggregation
#
# Project: Munchbox / Author: Alex Freidah
#
# Receives logs from Promtail agents on all nodes via push API. Maintains
# 5-day log retention with TSDB filesystem backend for persistence. Exposes
# HTTP API for Grafana log queries.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "loki"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
node_pool       = "edge"
priority        = 50
job_description = "Loki centralized log aggregation with 5-day retention"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier1"
category           = "logging"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
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

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

# --- Persistent storage volume ---
volume = {
  name       = "loki-data"
  type       = "host"
  source     = "loki-data"
  read_only  = false
  mount_path = "/loki"
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "30s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration file ---
external_files = {
  enabled   = true
  base_path = "jobs/logging/loki/files"
}

external_templates = [
  {
    destination     = "local/config/config.yaml"
    source_file     = "config.yaml"
    env             = false
    perms           = "0644"
    change_mode     = "restart"
    change_signal   = ""
    left_delimiter  = ""
    right_delimiter = ""
  }
]

# --- Task definition ---
task = {
  name   = "loki"
  driver = "docker"

  config = {
    image = "grafana/loki:3.3.1"
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

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 3100
standard_http_check_enabled  = true
standard_http_check_path     = "/ready"
additional_tags              = ["logging", "loki", "observability"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions ---
resource_tiers = {
  medium = {
    cpu            = 500
    memory         = 512
    ephemeral_disk = 1000
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
    healthy_deadline  = "5m"
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
