# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Hashi-UI Nomad and Consul cluster management dashboard
# -------------------------------------------------------------------------------

job_name        = "hashi-ui"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
namespace       = "default"
priority        = 50
job_description = "Hashi-UI dashboard for Nomad and Consul management"
deployment_profile = "standard"
meta_profile       = "standard"
category           = "infrastructure"
restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"
reschedule_preset = "standard"
resource_tier  = "medium"
network_preset = "host"
dns_servers    = ["192.168.68.62", "192.168.68.64"]

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

ports = [
  {
    name   = "http"
    static = 3100
  }
]

vault = {
  enabled       = true
  role          = "nomad-workloads"
  policy        = ""
  change_mode   = "restart"
  change_signal = "SIGTERM"
  env           = true
  namespace     = ""
  secrets       = {}
  aud           = ["vault.io"]
}

task = {
  name   = "hashi-ui"
  driver = "docker"

  identity = {
    env = true
    file = true
    aud = ["vault.io"]
  }

  config = {
    image        = "jippi/hashi-ui"
    network_mode = "host"
    ports        = ["http"]
    volumes = [
      "/opt/nomad/tls/nomad-agent-ca.pem:/etc/ssl/certs/nomad-agent-ca.pem"
    ]
  }

  templates = [
    {
      destination = "secrets/nomad.env"
      env         = true
      perms       = "0644"
      change_mode = "restart"
      data = <<-EOF
{{ with secret "secret/data/hashiuisecret" }}
NOMAD_ACL_TOKEN={{ .Data.data.token }}
{{ end }}
NOMAD_REGION=global
EOF
    }
  ]

  env = {
    NOMAD_ENABLE  = "1"
    NOMAD_ADDR    = "https://mccoy:4646"
    NOMAD_CACERT  = "/etc/ssl/certs/nomad-agent-ca.pem"
    CONSUL_ENABLE = "1"
    CONSUL_ADDR   = "http://mccoy:8500"
    CONSUL_CACERT = "/etc/ssl/certs/nomad-agent-ca.pem"
  }

  service = {
    name = "hashi-ui"
    port = "http"
    tags = [
      "traefik.enable=true",
      "traefik.http.routers.nomad.rule=Host(`nomad.munchbox`)",
      "traefik.http.routers.nomad.entrypoints=websecure",
      "traefik.http.routers.nomad.tls=true",
      "traefik.http.routers.nomad.middlewares=dashboard-allowlan@file",
      "traefik.http.services.nomad.loadbalancer.server.port=3100",
      "infrastructure",
      "nomad",
      "consul",
      "monitoring"
    ]

    checks = [
      {
        name     = "hashi-ui"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    ]
  }

  resources = {
    cpu    = 500
    memory = 512
  }

  kill_timeout = "30s"
  kill_signal  = "SIGTERM"
}
