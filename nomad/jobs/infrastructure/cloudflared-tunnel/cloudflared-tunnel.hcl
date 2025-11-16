# -------------------------------------------------------------------------------
# Cloudflare Tunnel — Ingress Gateway
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "cloudflared-tunnel"
job_type        = "system"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Cloudflare Tunnel ingress gateway with Consul KV templating"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "networking"

resource_tier  = "nano"
network_preset = "host"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

external_files = {
  enabled   = true
  base_path = "jobs/networking/cloudflared-tunnel/files"
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

task = {
  name   = "cloudflared"
  driver = "docker"

  config = {
    image      = "cloudflare/cloudflared:latest"
    force_pull = true
    args = [
      "tunnel",
      "--config", "/local/config.yml",
      "run"
    ]
  }

  resources = {
    cpu    = 50
    memory = 64
  }
}

standard_service_enabled = false

kill_timeout = "30s"
kill_signal  = "SIGTERM"
