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
namespace    = "default"
node_pool    = "all"

# --- Job metadata ---
meta = {
  version     = "3.3.1"
  updated     = "2025-10-31"
  description = "Promtail log collection agent - file-based for containers"
}

# --- Service configuration ---
standard_http_check_enabled = true
standard_http_check_path    = "/ready"
standard_http_check_port    = "http"
standard_service_name       = "promtail"

# --- Network configuration (host mode for system job) ---
network_preset = "host"
ports = [
  {
    name   = "http"
    static = 9080
  }
]

# --- DNS servers for Docker config ---
dns_servers = ["192.168.68.62", "192.168.68.64"]

# --- External configuration file ---
external_files = {
  enabled   = true
  base_path = "files"
}

external_templates = [
  {
    destination      = "local/config/config.yaml"
    source_file      = "config.yaml"
    change_mode      = "restart"
    left_delimiter   = "[["
    right_delimiter  = "]]"
  }
]

# --- Task definition ---
task = {
  name   = "promtail"
  driver = "docker"
  
  config = {
    image = "grafana/promtail:3.3.1"
    args  = ["-config.file=/etc/promtail/config.yaml"]
    ports = ["http"]
    dns_search_domains = ["service.consul"]
    dns_options = ["timeout:2", "attempts:3", "ndots:1"]
    
    # Host volumes for log collection
    volumes = [
      "/var/log/journal:/var/log/journal:ro",
      "/run/log/journal:/run/log/journal:ro",
      "/etc/machine-id:/etc/machine-id:ro",
      "local/config:/etc/promtail:ro",
      "/opt/nomad/alloc:/opt/nomad/alloc:ro",
      "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
    ]
  }
  
  # --- Resources ---
  resources = {
    cpu    = 150
    memory = 128
  }
  
  # --- Environment ---
  env = {
    TZ = "America/Los_Angeles"
  }
}

# --- Use node hostname in template ---
use_node_hostname = true

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Service tags ---
service_tags = ["logging", "promtail"]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
