# -------------------------------------------------------------------------------
# Cloudflare Tunnel — Ingress Gateway
#
# Project: Munchbox / Author: Alex Freidah
#
# Cloudflare Tunnel for external access to Munchbox services. Routes public
# domains through Cloudflare's network to local Traefik ingress controller.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "cloudflared-tunnel"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Cloudflare Tunnel ingress gateway with Consul KV templating"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "networking"

# --- Resource allocation ---
resource_tier = "nano"

# --- Network configuration ---
network_preset = "host"

dns_servers = ["192.168.68.62", "192.168.68.64"]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Restart policy ---
restart_attempts = 5
restart_interval = "5m"
restart_delay    = "10s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/cloudflared-tunnel/files"
}

external_templates = [
  {
    destination   = "local/credentials.json"
    source_file   = "credentials.json.tpl"
    env           = false
    perms         = "0644"
    change_mode   = "restart"
    change_signal = "SIGTERM"
  },
  {
    destination   = "local/config.yml"
    source_file   = "config.yml.tpl"
    env           = false
    perms         = "0644"
    change_mode   = "restart"
    change_signal = "SIGTERM"
  }
]

# --- Task definition ---
task = {
  name   = "cloudflared"
  driver = "docker"

  config = {
    image        = "cloudflare/cloudflared:latest"
    network_mode = "host"
    force_pull   = true
    args = [
      "tunnel",
      "--config", "/local/config.yml",
      "run"
    ]
  }
}

# --- Consul Connect ---
consul_connect_enabled = false

# --- Service registration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
