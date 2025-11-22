# -------------------------------------------------------------------------------
# Docker Registry — Private Container Image Repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Private Docker registry for Munchbox cluster accessible via HTTPS. Uses
# Traefik HTTP routing with bridge networking for external access. Stores
# images on local SSD for stability and performance.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "registry"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "utility"
namespace       = "default"
priority        = 50
job_description = "Docker registry with HTTPS routing via Traefik"

# -----------------------------------------------------------------------
# Deployment Strategy
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

# -----------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------

resource_tier = "small"

# -----------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------

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

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule Policies
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# External Configuration Files
# -----------------------------------------------------------------------

external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/registry/files"
}

external_templates = [
  {
    destination = "local/config/config.yml"
    source_file = "config.yml"
    env         = false
    perms       = "0644"
    change_mode = "restart"
  }
]

# -----------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------

task = {
  name   = "registry"
  driver = "docker"

  config = {
    image = "registry:2"
    ports = ["http"]
    volumes = [
      "local/config:/etc/docker/registry",
      "/opt/nomad/data/registry-data:/var/lib/registry"
    ]
  }

  env = {
    TZ = "UTC"
  }
}

# -----------------------------------------------------------------------
# Consul Connect
# -----------------------------------------------------------------------

consul_connect_enabled = false

# -----------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 5000
standard_http_check_enabled  = true
standard_http_check_path     = "/v2/"

additional_tags = [
  "registry",
  "docker",
  "infrastructure"
]

# -----------------------------------------------------------------------
# Traefik Routing
# -----------------------------------------------------------------------

traefik_enabled     = true
traefik_host        = "registry.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
