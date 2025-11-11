# -------------------------------------------------------------------------------
# Blackbox Exporter — Internal Endpoint Monitoring and Metrics Collection
#
# Project: Munchbox
# Author: Alex Freidah
#
# Runs blackbox exporter on static host port 9115 with host networking for
# Prometheus probe execution. Uses Consul service registration with LAN IP
# binding. Probes internal services and endpoints.
# -------------------------------------------------------------------------------

job_name        = "blackbox-exporter"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "all"
priority        = 50

job_description = "Blackbox exporter — internal endpoint monitoring and metrics collection"

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
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "tier-2"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "tiny"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "http"
    static = 9115
    port   = 9115
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "5s"
restart_mode     = "delay"

reschedule_preset = "extended"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "exporter"
  driver = "docker"

  config = {
    image        = "prom/blackbox-exporter:v0.25.0"
    ports        = ["http"]
    network_mode = "host"
    args = [
      "--config.file=/local/blackbox.yml"
    ]
  }

  templates = [
    {
      destination = "local/blackbox.yml"
      change_mode = "signal"
      change_signal = "SIGHUP"
      perms       = "0644"
      data        = <<-EOF
modules:
  https_2xx:
    prober: http
    http:
      method: GET
      fail_if_not_ssl: true
      preferred_ip_protocol: "ip4"
      valid_http_versions: ["HTTP/1.1","HTTP/2.0"]
      tls_config:
        insecure_skip_verify: false
EOF
    }
  ]

  service = {
    name     = "blackbox-exporter"
    port     = "http"
    provider = "consul"
    address_mode = "host"
    tags = [
      "metrics",
      "prometheus"
    ]
    checks = [
      {
        name     = "blackbox-health"
        type     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "2s"
      }
    ]
  }

  resources = {
    cpu    = 50
    memory = 64
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  tiny = {
    cpu             = 50
    memory          = 64
    ephemeral_disk  = 100
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  canary = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "15m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier-2 = {
    tier = "tier-2"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  extended = {
    max_reschedules = 3
    delay           = "5s"
    delay_function  = "exponential"
    unlimited       = false
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  host = {
    mode = "host"
  }
}
