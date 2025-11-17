# -------------------------------------------------------------------------------
# Docker Registry UI — Web Interface for Registry Mirror
# -------------------------------------------------------------------------------

job_name        = "registry-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Docker registry web UI via Connect mesh"

deployment_profile = "standard"
meta_profile       = "tier2"
category           = "infrastructure"

resource_tier  = "small"
network_preset = "bridge"

ports = [
  {
    name = "http"
    to   = 80
  }
]

restart_attempts = 5
restart_interval = "10m"
restart_delay    = "30s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "registry-ui"
  driver = "docker"

  config = {
    image = "joxit/docker-registry-ui:latest"
    ports = ["http"]
  }

  env = {
    REGISTRY_URL         = "https://registry-ui.munchbox"
    NGINX_PROXY_PASS_URL = "http://localhost:5000"
    SINGLE_REGISTRY      = "true"
    REGISTRY_TITLE       = "Docker Registry Mirror"
    DELETE_IMAGES        = "false"
    TZ                   = "UTC"
  }

  service = {
    name     = "registry-ui"
    port     = "http"
    provider = "consul"
    tags = [
      "traefik.enable=true",
      "traefik.http.routers.registry-ui.rule=Host(`registry-ui.munchbox`)",
      "traefik.http.routers.registry-ui.entrypoints=websecure",
      "traefik.http.routers.registry-ui.tls=true",
      "traefik.http.routers.registry-ui.middlewares=dashboard-allowlan@file",
      "traefik.http.services.registry-ui.loadbalancer.server.port=80",
      "registry-ui",
      "docker",
      "ui"
    ]
    checks = [
      {
        name         = "registry-ui-http"
        type         = "http"
        port         = "http"
        path         = "/"
        interval     = "30s"
        timeout      = "5s"
        address_mode = "alloc"
      }
    ]
  }

  resources = {
    cpu    = 150
    memory = 128
  }
}

# -----------------------------------------------------------------------
# Consul Connect Configuration
# -----------------------------------------------------------------------

consul_connect_enabled = true

connect_upstreams = [
  {
    destination_name = "docker-mirror"
    local_bind_port  = 5000
  }
]

connect_sidecar_resources = {
  cpu    = 100
  memory = 64
}

# -----------------------------------------------------------------------
# Disable Standard Service (using custom instead)
# -----------------------------------------------------------------------

standard_service_enabled = false

kill_timeout = "30s"
kill_signal  = "SIGTERM"
