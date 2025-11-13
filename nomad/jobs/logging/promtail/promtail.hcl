# jobs/logging/promtail/promtail.hcl
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
region       = "global"
datacenters  = ["pi-dc"]
namespace    = "default"
node_pool    = "all"
priority     = 50

job_description = "Promtail log collection agent - systemd journal and Nomad allocation logs"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "monitoring"

# --- Resource allocation ---
resource_tier = "tiny"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9080
  }
]

# --- DNS configuration ---
dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# --- Service registration ---
standard_service_name       = "promtail"
standard_http_check_enabled = true
standard_http_check_path    = "/ready"
standard_http_check_port    = "http"

service_tags = ["logging", "promtail", "metrics"]

# --- External configuration file ---
external_files = {
  enabled   = true
  base_path = "jobs/logging/promtail/files"
}

external_templates = [
  {
    destination     = "local/config/config.yaml"
    source_file     = "config.yaml"
    env             = false
    perms           = "0644"
    change_mode     = "restart"
    change_signal   = "SIGTERM"
    left_delimiter  = "[["
    right_delimiter = "]]"
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
    dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
    
    volumes = [
      "/var/log/journal:/var/log/journal:ro",
      "/run/log/journal:/run/log/journal:ro",
      "/etc/machine-id:/etc/machine-id:ro",
      "local/config:/etc/promtail:ro",
      "/opt/nomad/alloc:/opt/nomad/alloc:ro",
      "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
    ]
  }
  
  resources = {
    cpu    = 150
    memory = 128
  }
  
  env = {
    TZ = "America/Los_Angeles"
    # HOSTNAME will be set by template if use_node_hostname is true
  }
}

# --- Enable node hostname injection in template ---
use_node_hostname = true

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"

# --- Resource tier definitions (required by pack) ---
resource_tiers = {
  tiny = {
    cpu            = 150
    memory         = 128
    ephemeral_disk = 200
  }
}

# --- Network presets (required by pack) ---
network_presets = {
  host = {
    mode = "host"
  }
}

# --- Deployment profiles (required by pack) ---
deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
  }
}

# --- Meta profiles (required by pack) ---
meta_profiles = {
  tier2 = {
    tier = "important"
  }
}
