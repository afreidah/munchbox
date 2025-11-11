# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Health Checker internal service health monitoring and alerting
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
meta_profile       = "standard"
category           = "utility"
restart_attempts = 2
restart_interval = "30s"
restart_delay    = "5s"
restart_mode     = "fail"
reschedule_preset = "standard"
resource_tier  = "small"
network_preset = "bridge"

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "goren"
  }
]

ports = [
  {
    name   = "http"
    static = 18080
  }
]

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

  service = {
    name = "health-checker"
    port = "http"
    tags = [
      "traefik.enable=true",
      "traefik.http.routers.health.rule=Host(`health.munchbox`)",
      "traefik.http.routers.health.entrypoints=websecure",
      "traefik.http.routers.health.tls=true",
      "traefik.http.routers.health.middlewares=dashboard-allowlan@file",
      "traefik.http.services.health.loadbalancer.server.port=18080",
      "traefik.http.services.health.loadbalancer.server.scheme=http",
      "traefik.http.services.health.loadbalancer.healthcheck.path=/health",
      "traefik.http.services.health.loadbalancer.healthcheck.interval=30s",
      "traefik.http.services.health.loadbalancer.healthcheck.timeout=5s",
      "go",
      "health",
      "monitoring"
    ]

    checks = [
      {
        name     = "health-checker"
        type     = "http"
        path     = "/health"
        interval = "15s"
        timeout  = "3s"
      }
    ]
  }

  resources = {
    cpu    = 200
    memory = 128
  }
}
