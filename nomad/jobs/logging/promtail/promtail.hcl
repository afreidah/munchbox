# -------------------------------------------------------------------------------
# Promtail — Log collection agent running on all nodes
#
# Project: Munchbox / Author: Alex Freidah
#
# System job that runs on every node in the cluster. Collects logs from systemd
# journal, Nomad allocations, and Docker containers for forwarding to Loki.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name     = "promtail"
job_type     = "system"
category     = "monitoring"
datacenters  = ["pi-dc"]
region       = "global"

# --- Service configuration ---
standard_http_check_enabled = true
standard_http_check_path    = "/ready"
standard_http_check_port    = "http"
standard_service_name       = "promtail"

# --- Network configuration ---
network_preset = "bridge"
ports = [
  {
    name = "http"
    to   = 9080
  }
]

# --- External configuration file ---
external_files = {
  enabled   = true
  base_path = "jobs/logging/promtail/files"
}

external_templates = [
  {
    destination   = "/etc/promtail/config.yml"
    source_file   = "config.yaml"
    env           = false
    perms         = "0644"
    change_mode   = "restart"
    change_signal = "SIGTERM"
  }
]

# --- Task definition ---
task = {
  name   = "promtail"
  driver = "docker"
  
  config = {
    image = "grafana/promtail:2.9.4"
    args  = ["-config.file=/etc/promtail/config.yml"]
    ports = ["http"]
    
    # Host volumes for log collection
    volumes = [
      "/var/log:/var/log:ro",
      "/run/log/journal:/run/log/journal:ro",
      "/var/log/journal:/var/log/journal:ro",
      "/var/lib/docker/containers:/var/lib/docker/containers:ro",
      "/opt/nomad/alloc:/opt/nomad/alloc:ro",
      "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
    ]
  }
  
  # --- Resources for system job ---
  resources = {
    tier = "small"
  }
  
  # --- Environment ---
  env = {
    TZ = "America/Los_Angeles"
  }
}

# --- Resource tier definitions ---
resource_tiers = {
  small = {
    cpu    = 100
    memory = 128
  }
}

# --- Service tags ---
service_tags = ["monitoring", "promtail", "logging", "system"]
