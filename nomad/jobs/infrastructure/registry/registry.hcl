# -------------------------------------------------------------------------------
# Docker Registry — Private Container Image Repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Private Docker registry for Munchbox cluster. Stores images on shared storage
# for portability across nodes with proper CORS headers for multi-host access.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------

job_name        = "registry"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Private Docker registry with CORS support - portable storage"

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
    name   = "registry"
    to     = 5000
    static = 5000
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
    ports = ["registry"]
    volumes = [
      "local/config:/etc/docker/registry",
      "/mnt/gdrive/munchbox-data/registry:/var/lib/registry"
    ]
  }

  env = {
    TZ = "UTC"
  }

  service = {
    name     = "docker-mirror"
    port     = "registry"
    provider = "consul"
    tags     = ["registry", "docker"]
    checks = [
      {
        name     = "registry-http"
        type     = "http"
        path     = "/v2/"
        interval = "10s"
        timeout  = "3s"
        check_restart = {
          limit = 3
          grace = "10s"
        }
      }
    ]
  }
}

# -----------------------------------------------------------------------
# Consul Connect
# -----------------------------------------------------------------------

consul_connect_enabled = true

# -----------------------------------------------------------------------
# Service Registration
# -----------------------------------------------------------------------

standard_service_enabled = false

# -----------------------------------------------------------------------
# Termination
# -----------------------------------------------------------------------

kill_timeout = "30s"
kill_signal  = "SIGTERM"
