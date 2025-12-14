# -------------------------------------------------------------------------------
# Waypoint Runner — Build and Deployment Agent
#
# Project: Munchbox / Author: Alex Freidah
#
# Waypoint runner deployment that connects to server via TLS with token auth.
# Reads bootstrap token from waypoint-data volume (shared with server).
# Mounts Docker socket for build operations.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "waypoint-runner"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Waypoint runner — connects to server with TLS token auth, Docker socket mounted"

# --- Deployment and metadata ---
deployment_profile = "canary"
meta_profile       = "tier2"
category           = "automation"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

dns_servers  = ["192.168.68.64", "192.168.68.62"]
dns_searches = ["service.consul"]
dns_options  = ["timeout:2", "attempts:3", "ndots:1"]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# --- Persistent storage volume ---
volume = {
  name       = "waypoint-data"
  type       = "host"
  source     = "waypoint-data"
  mount_path = "/data"
  read_only  = true
}

# --- Restart policy ---
restart_attempts = 3
restart_interval = "30s"
restart_delay    = "5s"
restart_mode     = "delay"

# --- Reschedule policy ---
reschedule_preset = "standard"

# --- Task definition ---
task = {
  name   = "runner"
  driver = "docker"

  config = {
    image      = "registry.service.consul:5000/ops-waypoint-image:latest"
    entrypoint = ["/bin/sh", "-c"]
    args = [
      "export WAYPOINT_SERVER_TOKEN=$(cat /data/waypoint-token) && exec waypoint runner agent"
    ]
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
  }

  env = {
    TZ                              = "UTC"
    WAYPOINT_SERVER_ADDR            = "mccoy:9701"
    WAYPOINT_SERVER_TLS             = "1"
    WAYPOINT_SERVER_TLS_SKIP_VERIFY = "1"
  }

  resources = {
    cpu    = 300
    memory = 256
  }
}

# --- Standard service configuration ---
standard_service_enabled = false

# --- Termination ---
kill_timeout = "30s"
kill_signal  = "SIGTERM"
