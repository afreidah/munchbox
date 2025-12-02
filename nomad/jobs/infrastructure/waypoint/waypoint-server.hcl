# -------------------------------------------------------------------------------
# Waypoint Server — Deployment Pipeline Orchestration
#
# Project: Munchbox / Author: Alex Freidah
#
# Waypoint server deployment with local persistence, host networking, and
# dual gRPC and UI service registration.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "waypoint-server"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Waypoint server (local dev, no auth) — gRPC and UI services"

# --- Deployment and metadata ---
deployment_profile = "canary"
meta_profile       = "tier2"
category           = "automation"

# --- Resource allocation ---
resource_tier = "small"

# --- Network configuration ---
network_preset = "host"

ports = [
  {
    name   = "grpc"
    static = 9701
    to     = 9701
  },
  {
    name   = "ui"
    static = 9702
    to     = 9702
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

# --- Persistent storage volume ---
volume = {
  name       = "waypoint-data"
  type       = "host"
  source     = "waypoint-data"
  mount_path = "/var/lib/waypoint"
  read_only  = false
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
  name   = "server"
  driver = "docker"

  config = {
    image      = "registry.munchbox.cc/ops-waypoint-image:latest"
    entrypoint = ["/bin/sh", "-lc"]
    args = [
      "mkdir -p /var/lib/waypoint && exec waypoint server run -accept-tos -db=/var/lib/waypoint/waypoint.db -listen-grpc=0.0.0.0:9701 -listen-http=0.0.0.0:9702"
    ]
    ports = ["grpc", "ui"]
  }

  services = [
    {
      name     = "waypoint-grpc"
      port     = "grpc"
      provider = "consul"
      tags     = ["waypoint", "grpc"]
    },
    {
      name     = "waypoint-ui"
      port     = "ui"
      provider = "consul"
      tags     = ["waypoint", "ui"]
    }
  ]

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
