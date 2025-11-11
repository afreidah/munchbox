# -------------------------------------------------------------------------------
#  Cloudflare Tunnel — Ingress Gateway
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Routes external domains to internal Traefik via Cloudflare Tunnel. Runs as
#  system job on ingress node (mccoy) with host networking. Tunnel credentials
#  and configuration templates rendered from Consul KV.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Job Configuration
# -----------------------------------------------------------------------

job_name        = "cloudflared-tunnel"
job_type        = "system"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Cloudflare Tunnel ingress gateway with Consul KV templating"

# -----------------------------------------------------------------------
# Deployment Profile & Metadata
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "standard"
category           = "web"

# -----------------------------------------------------------------------
# Restart Behavior
# -----------------------------------------------------------------------
# Note: System jobs do not support reschedule policies

restart_attempts = 5
restart_interval = "5m"
restart_delay    = "10s"
restart_mode     = "delay"

# -----------------------------------------------------------------------
# Resource Tier & Network Configuration
# -----------------------------------------------------------------------

resource_tier  = "nano"
network_preset = "host"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------
# Restrict cloudflared to ingress node only

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "cloudflared"
  driver = "docker"

  # Docker container runtime configuration
  config = {
    image        = "cloudflare/cloudflared:latest"
    force_pull   = true
    network_mode = "host"
    args = [
      "tunnel",
      "--config", "/etc/cloudflared/config.yml",
      "run"
    ]
    volumes = [
      "local/config.yml:/etc/cloudflared/config.yml:ro",
      "local/credentials.json:/etc/cloudflared/credentials.json:ro"
    ]
  }

  # Nomad templates rendered from Consul KV
  templates = [
    {
      destination = "local/credentials.json"
      change_mode = "restart"
      change_signal = "SIGTERM"
      data        = <<-EOF
{{ key "secrets/cloudflared/credentials.json" }}
EOF
    },
    {
      destination = "local/config.yml"
      change_mode = "restart"
      change_signal = "SIGTERM"
      data        = <<-EOF
tunnel: {{ key "secrets/cloudflared/tunnel_uuid" }}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: "alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: alexfreidah.com }

  - hostname: "www.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: www.alexfreidah.com }

  - hostname: "resume.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: resume.alexfreidah.com }

  - hostname: "k3s-status.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: k3s-status.alexfreidah.com }

  - service: http_status:404

warp-routing:
  enabled: false
EOF
    }
  ]

  # Resource allocation for nano tier
  resources = {
    tier = "nano"
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  nano = {
    cpu             = 50
    memory          = 64
    ephemeral_disk  = 100
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

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  canary = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  standard = {
    tier = "standard"
  }
}
