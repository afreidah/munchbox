# -------------------------------------------------------------------------------
# Hashi-UI — Nomad Job
#
# - Runs the jippi/hashi-ui Docker image for Nomad/Consul dashboards.
# - Exposes web UI on port 3000.
# - Registers with Consul for service discovery and health checks.
# - Connects to Nomad and Consul agents using cluster environment variables.
# - Constrains to node "mccoy" and ARM architecture.
# - Injects Nomad ACL token securely from Vault/OpenBao.
# -------------------------------------------------------------------------------
job "hashi-ui" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "server" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    # --- Vault block to declare secret dependency ---
    vault {
      policies    = ["root"]
      change_mode = "noop"
    }

    network {
      port "http" {
        static = 3000
      }
    }

    task "hashi-ui" {
      driver = "docker"

      config {
        image        = "jippi/hashi-ui"
        network_mode = "host"
        volumes = [
          "/opt/nomad/tls/nomad-agent-ca.pem:/etc/ssl/certs/nomad-agent-ca.pem",
        ]
      }

      template {
        data        = <<EOH
      NOMAD_TOKEN={{ with secret "secret/hashiuisecret" }}{{ .Data.data.token }}{{ end }}
      EOH
        destination = "secrets/nomad.env"
        env         = true
      }

      env {
        NOMAD_ENABLE  = "1"
        NOMAD_ADDR    = "https://mccoy:4646"
        NOMAD_CACERT  = "/etc/ssl/certs/nomad-agent-ca.pem"
        CONSUL_ENABLE = "1"
        CONSUL_CACERT = "/etc/ssl/certs/nomad-agent-ca.pem"
        CONSUL_ADDR   = "http://mccoy:8500"
      }

      service {
        name = "hashi-ui"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.nomad.rule=Host(`nomad.munchbox`)",
          "traefik.http.routers.nomad.entrypoints=websecure",
          "traefik.http.routers.nomad.tls=true",
        ]

        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
