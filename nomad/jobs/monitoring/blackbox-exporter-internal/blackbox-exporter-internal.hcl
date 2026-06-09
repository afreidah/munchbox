# -------------------------------------------------------------------------------
# Blackbox Exporter (Internal) — On-Prem Network Probe
#
# Project: Munchbox / Author: Alex Freidah
#
# Sibling to blackbox-exporter-external. Runs on an on-prem nomad client so
# probes exercise direct LAN reachability — pihole web UIs, internal-only
# Traefik routes, anything not meant to ride the WireGuard tunnel.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "blackbox-exporter-internal"
image        = "prom/blackbox-exporter:v0.28.0"
port         = 9115
static_port  = 9115
host_network = true
size         = "tiny"
memory       = 64
vault        = true

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/health"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
args = [
  "--config.file=/etc/blackbox/config/blackbox.yml",
  "--web.listen-address=0.0.0.0:9115"
]

# --- Configuration templates ---
templates = [
  { src = "blackbox.yml", dest = "/etc/blackbox/config/blackbox.yml" }
]

# --- Service tags ---
tags = ["monitoring", "blackbox-exporter", "probes", "internal", "metrics"]

# --- Placement: any on-prem nomad client (NOT oracle), off ingress nodes. ---
node = "any"
constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" },
  { attribute = "$${meta.role}", operator = "!=", value = "ingress" }
]
