# -------------------------------------------------------------------------------
# Health Checker — Internal Service Health Monitoring
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "health-checker"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
namespace       = "default"
priority        = 50
job_description = "Health checker service for cluster monitoring"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "monitoring"

resource_tier  = "small"
network_preset = "bridge"

dns_servers = ["192.168.68.62", "192.168.68.64"]

ports = [
  {
    name = "http"
    to   = 18080
  }
]

# --- Placement constraints ---
constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "goren"
  }
]

# --- Restart policy ---
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# --- Reschedule policy ---
reschedule_preset = "standard"

task = {
  name   = "health-checker"
  driver = "docker"

  config = {
    image = "registry.munchbox/health-checker"
    ports = ["http"]
    volumes = [
      "/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro"
    ]
    args = ["--service", "k3s", "--port", "18080", "--interval", "10"]
  }
}

consul_connect_enabled = false

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 18080
standard_http_check_enabled  = true
standard_http_check_path     = "/health"

additional_tags = [
  "traefik.enable=true",
  "go",
  "health",
  "monitoring"
]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
