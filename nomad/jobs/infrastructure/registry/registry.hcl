# -------------------------------------------------------------------------------
# Docker Registry — Container Image Storage with UI
#
# Project: Munchbox / Author: Alex Freidah
#
# Docker Registry v2 for storing and distributing container images within the
# cluster. Includes web UI for browsing repositories and managing images.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "registry"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
namespace       = "default"
priority        = 50
job_description = "Docker Registry with web UI and persistent storage"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
network_preset = "bridge"

ports = [
  {
    name = "http"
    to   = 5000
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }
]

# --- Restart policy ---
restart_attempts = 5
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Storage ---
volume = {
  name       = "registry-data"
  type       = "host"
  source     = "registry-data"
  mount_path = "/var/lib/registry"
  read_only  = false
}

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/registry/files"
}

external_templates = [
  {
    destination = "local/config.yml"
    source_file = "registry-config.yml"
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "registry"
  driver = "docker"

  config = {
    image              = "registry:2"
    image_pull_timeout = "10m"
    ports              = ["http"]
    args               = ["serve", "/local/config.yml"]
  }

  resources = {
    cpu    = 500
    memory = 512
  }
}

# --- Consul Connect service mesh ---
consul_connect_enabled = false

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 5000
standard_http_check_enabled  = true
standard_http_check_path     = "/v2/"

additional_tags = [
  "docker",
  "registry",
  "infrastructure"
]

# --- Traefik routing ---
traefik_enabled     = true
traefik_host        = "registry.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
