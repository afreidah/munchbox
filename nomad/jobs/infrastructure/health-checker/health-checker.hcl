# -------------------------------------------------------------------------------
# Health Checker — Internal Service Health Monitoring
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job_name        = "health-checker"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Health checker service for cluster monitoring"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "monitoring"

resource_tier  = "small"
network_preset = "host"

ports = [
  {
    name   = "http"
    static = 18080
  }
]

#constraints = [
#  {
#    attribute = "$${node.unique.name}"
#    operator  = "="
#    value     = "goren"
#  }
#]

task = {
  name   = "health-checker"
  driver = "docker"
  config = {
    image = "docker-mirror.service.consul:5000/health-checker"
    ports = ["http"]
    volumes = [
      "/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro"
    ]
    args = ["--service", "k3s", "--port", "18080", "--interval", "10"]
  }
  resources = {
    cpu    = 200
    memory = 128
  }
}

standard_service_enabled     = true
standard_service_port        = "http"
standard_service_port_number = 18080
standard_http_check_enabled  = true
standard_http_check_path     = "/health"
additional_tags = ["go", "health", "monitoring"]

kill_timeout = "30s"
kill_signal  = "SIGTERM"
