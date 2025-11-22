# -------------------------------------------------------------------------------
# Docker Registry UI — Web Interface for Registry Mirror
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based interface for browsing Docker registry contents. Provides visual
# access to stored images and tags with read-only access.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "registry-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "utility"
namespace       = "default"
priority        = 50
job_description = "Docker registry web UI"

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
    to   = 80
  }
]

dns_servers  = ["192.168.68.62", "192.168.68.64"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# -----------------------------------------------------------------------
# Restart & Reschedule Policies
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "registry-ui"
  driver = "docker"

  config = {
    image = "joxit/docker-registry-ui:latest"
    ports = ["http"]
  }

  env = {
    REGISTRY_URL         = "https://registry.munchbox"
    NGINX_PROXY_PASS_URL = ""
    SINGLE_REGISTRY      = "true"
    REGISTRY_TITLE       = "Docker Registry Mirror"
    DELETE_IMAGES        = "false"
    TZ                   = "UTC"
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
standard_service_port_number = 80
standard_http_check_enabled  = true
standard_http_check_path     = "/"

additional_tags = [
  "registry-ui",
  "docker",
  "ui",
  "infrastructure"
]

# -----------------------------------------------------------------------
# Traefik Routing
# -----------------------------------------------------------------------

traefik_enabled     = true
traefik_host        = "registry-ui.munchbox"
traefik_entrypoints = "websecure"
traefik_tls_enabled = true
traefik_middlewares = "dashboard-allowlan@file"

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
