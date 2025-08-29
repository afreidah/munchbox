# -------------------------------------------------------------------------------
# Hashi-UI — Nomad Job
#
# - Runs the jippi/hashi-ui Docker image for Nomad/Consul dashboards.
# - Exposes web UI on port 3000.
# - Registers with Consul for service discovery and health checks.
# - Connects to Nomad and Consul agents at 192.168.1.225.
# -------------------------------------------------------------------------------
job "hashi-ui" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"

  group "server" {
    count = 1

    task "hashi-ui" {
      driver = "docker"

      config {
        image        = "jippi/hashi-ui"
        network_mode = "host"
      }

      service {
        port = "http"

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      env {
        NOMAD_ENABLE = 1
        NOMAD_ADDR   = "192.168.1.225:4646"

        CONSUL_ENABLE = 1
        CONSUL_ADDR   = "192.168.1.225:8500"
      }

      resources {
        cpu    = 500
        memory = 512

        network {
          port "http" {
            static = 3000
          }
        }
      }
    }
  }
}
