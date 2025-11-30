# -------------------------------------------------------------------------------
# Hashi-UI — Nomad and Consul Cluster Management Dashboard
#
# Project: Munchbox / Author: Alex Freidah
#
# Unified dashboard for Nomad and Consul cluster management. Pulls Nomad ACL
# token from Vault for secure API access. Connects to local Nomad (https) and
# Consul (http) agents.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "hashi-ui"
type  = "service"
image = "jippi/hashi-ui"
port  = 3100
static_port = 3100
host_network = true
node = "nomad-client-03"
size = "small"

# --- Vault integration ---
vault = true

# --- Volume mounts ---
volumes = [
  "/opt/nomad/tls/nomad-agent-ca.pem:/etc/ssl/certs/nomad-agent-ca.pem"
]

# --- Environment variables ---
env = {
  NOMAD_ENABLE  = "1"
  NOMAD_ADDR    = "https://127.0.0.1:4646"
  NOMAD_CACERT  = "/etc/ssl/certs/nomad-agent-ca.pem"
  NOMAD_REGION  = "global"
  CONSUL_ENABLE = "1"
  CONSUL_ADDR   = "http://127.0.0.1:8500"
}

# --- Vault template for Nomad token ---
templates = [
  { src = "nomad.env.tpl", dest = "/secrets/nomad.env", vault = true, env = true }
]

# --- Traefik integration ---
traefik = true
traefik_host = "hashi-ui.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Service tags ---
tags = [
  "infrastructure",
  "nomad",
  "consul",
  "monitoring"
]
