# -------------------------------------------------------------------------------
# Promtail — Log Collection Agent
#
# Project: Munchbox / Author: Alex Freidah
#
# System job collecting logs from systemd journal and Nomad allocation logs on
# every node. Forwards to Loki for centralized aggregation and querying via
# Grafana dashboards.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "promtail"
type         = "system"
image        = "grafana/promtail:3.5"
port         = 9080
static_port  = 9080
host_network = true
size         = "tiny"
memory       = 192    # Some instances peak at 125MB, give headroom

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/ready"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
args = ["-config.file=/etc/promtail/config.yaml"]

# --- Host volume mounts ---
volumes = [
  "/var/log/journal:/var/log/journal:ro",
  "/run/log/journal:/run/log/journal:ro",
  "/etc/machine-id:/etc/machine-id:ro",
  "/var/lib/nomad/alloc:/var/lib/nomad/alloc:ro"
]

# --- Configuration templates ---
templates = [
  { src = "config.yaml", dest = "/etc/promtail/config.yaml" }
]

# --- Service tags ---
tags = ["logging", "promtail", "metrics"]
