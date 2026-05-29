# -------------------------------------------------------------------------------
# Blackbox Exporter — Network Probe and Endpoint Monitoring
#
# Project: Munchbox / Author: Alex Freidah
#
# Probes HTTP, HTTPS, DNS, TCP, and ICMP endpoints to verify availability and
# response times. Uses host networking for direct network access. Scraped by
# Prometheus for synthetic monitoring metrics.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "blackbox-exporter-external"
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
tags = ["monitoring", "blackbox-exporter", "probes", "external"]

# --- Placement: Oracle cloud ---
# Runs off-LAN so probes exercise true outside->in reachability for our
# published services (Cloudflare tunnel + the dual ingress path), instead
# of short-circuiting inside the home network.
node = "any"
constraints = [
  { attribute = "$${meta.cloud}", operator = "=", value = "oracle" }
]
