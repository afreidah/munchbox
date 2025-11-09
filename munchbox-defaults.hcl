################################################################################
# Project: Munchbox
# Author: Alex Freidah
#
# Munchbox Standard Defaults
# 
# This file defines organization-wide defaults for all Nomad jobs including
# resource tiers, Traefik patterns, Vault configuration, and standard
# operational parameters. Individual jobs only need to override what's unique.
################################################################################

# -----------------------------------------------------------------------------
# Resource Tiers
# -----------------------------------------------------------------------------

resource_tiers = {
  nano = {
    cpu        = 50
    memory     = 64
    memory_max = 128
  }
  
  tiny = {
    cpu        = 100
    memory     = 128
    memory_max = 256
  }
  
  small = {
    cpu        = 250
    memory     = 256
    memory_max = 512
  }
  
  medium = {
    cpu        = 500
    memory     = 512
    memory_max = 1024
  }
  
  large = {
    cpu        = 1000
    memory     = 1024
    memory_max = 2048
  }
  
  xlarge = {
    cpu        = 2000
    memory     = 2048
    memory_max = 4096
  }
  
  xxlarge = {
    cpu        = 4000
    memory     = 4096
    memory_max = 8192
  }
}

# -----------------------------------------------------------------------------
# Standard Munchbox Configuration
# -----------------------------------------------------------------------------

defaults = {
  # Infrastructure
  datacenters = ["dc1"]
  namespace   = "default"
  priority    = 50
  
  # Networking
  network_mode = "bridge"
  dns_servers  = ["172.17.0.1"]
  dns_searches = ["service.consul"]
  
  # Job behavior
  job_type = "service"
  count    = 1
  
  # Update strategy (safe defaults)
  update = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = false
    canary            = 0
    stagger           = "30s"
  }
  
  # Restart policy
  restart = {
    attempts = 2
    interval = "30m"
    delay    = "15s"
    mode     = "fail"
  }
  
  # Reschedule policy
  reschedule = {
    attempts       = 2
    interval       = "24h"
    delay          = "30s"
    delay_function = "exponential"
    max_delay      = "1h"
    unlimited      = false
  }
  
  # Health check defaults
  health_check = {
    interval              = "10s"
    timeout               = "2s"
    check_restart_limit   = 3
    check_restart_grace   = "10s"
  }
  
  # Logging
  log_retention = {
    max_files     = 10
    max_file_size = 10
  }
}

# -----------------------------------------------------------------------------
# Traefik Standard Tags
# -----------------------------------------------------------------------------

traefik_defaults = {
  # Standard entrypoints
  entrypoint_http    = "web"
  entrypoint_https   = "websecure"
  
  # Standard domain
  domain = "munchbox.local"
  
  # Common middlewares
  middlewares = {
    ratelimit_standard = "ratelimit-100"
    ratelimit_api      = "ratelimit-1000"
    compress           = "compress"
    security_headers   = "security-headers"
  }
  
  # TLS defaults
  tls = {
    enabled      = true
    certresolver = "letsencrypt"
  }
}

# -----------------------------------------------------------------------------
# Vault Standard Configuration
# -----------------------------------------------------------------------------

vault_defaults = {
  # Namespace (if using Vault Enterprise)
  namespace = ""
  
  # Standard behavior
  change_mode   = "restart"
  change_signal = "SIGTERM"
  env           = true
  
  # Policy naming convention: {job_name}-policy
  # Secrets path convention: secret/data/{job_name}/*
}

# -----------------------------------------------------------------------------
# Workload Identity Defaults
# -----------------------------------------------------------------------------

identity_defaults = {
  env         = true
  file        = false
  change_mode = "restart"
}

# -----------------------------------------------------------------------------
# Standard Constraints
# -----------------------------------------------------------------------------

standard_constraints = [
  {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
]

# -----------------------------------------------------------------------------
# Standard Meta Tags
# -----------------------------------------------------------------------------

standard_meta = {
  managed_by  = "levant"
  project     = "munchbox"
  environment = "production"
}

# -----------------------------------------------------------------------------
# Docker Registry Defaults
# -----------------------------------------------------------------------------

docker_defaults = {
  # Private registry (if used)
  registry = ""
  
  # Standard logging driver
  logging = {
    type = "fluentd"
    config = {
      fluentd-address = "localhost:24224"
      tag             = "{{.Name}}"
    }
  }
  
  # DNS defaults
  dns_servers        = ["172.17.0.1"]
  dns_search_domains = ["service.consul"]
  
  # Force pull in production
  force_pull = false
}

# -----------------------------------------------------------------------------
# Service Discovery Defaults
# -----------------------------------------------------------------------------

consul_defaults = {
  provider = "consul"
  
  # Standard tags applied to all services
  standard_tags = [
    "munchbox",
    "production"
  ]
}
