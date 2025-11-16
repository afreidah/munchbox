# -------------------------------------------------------------------------------
# Hashi-UI — Nomad and Consul Cluster Management Dashboard
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based dashboard for monitoring and managing Nomad and Consul clusters.
# Provides unified view of cluster state, job management, and service discovery.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "hashi-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Hashi-UI dashboard for Nomad and Consul management"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

# --- Resource allocation ---
resource_tier = "medium"

# --- Network configuration ---
network_preset = "host"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

ports = [
  {
    name   = "http"
    static = 3100
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Vault integration ---
vault_role = "nomad-workloads"

# --- External configuration files ---
external_files = {
  enabled   = true
  base_path = "jobs/infrastructure/hashi-ui/files"
}

external_templates = [
  {
    destination = "secrets/nomad.env"
    source_file = "nomad.env.tpl"
    env         = true
    perms       = "0600"
    change_mode = "restart"
  }
]

# --- Task definition ---
task = {
  name   = "hashi-ui"
  driver = "docker"

  config = {
    image = "jippi/hashi-ui"
    ports = ["http"]
    volumes = [
      "/opt/nomad/tls/nomad-agent-ca.pem:/etc/ssl/certs/nomad-agent-ca.pem"
    ]
  }

  env = {
    NOMAD_ENABLE  = "1"
    NOMAD_ADDR    = "https://mccoy:4646"
    NOMAD_CACERT  = "/etc/ssl/certs/nomad-agent-ca.pem"
    NOMAD_REGION  = "global"
    CONSUL_ENABLE = "1"
    CONSUL_ADDR   = "http://mccoy:8500"
    CONSUL_CACERT = "/etc/ssl/certs/nomad-agent-ca.pem"
  }

  resources = {
    cpu    = 500
    memory = 512
  }
}

# --- Standard service configuration ---
standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 3100
standard_http_check_enabled  = true
standard_http_check_path     = "/"
additional_tags = [
  "infrastructure",
  "nomad",
  "consul",
  "monitoring"
]

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
