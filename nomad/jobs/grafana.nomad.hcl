# -------------------------------------------------------------------------------
# Grafana — Nomad Job (with persistent data under /opt/nomad/data)
#
# - Single instance on core pool
# - Host networking so Grafana can reach Prometheus at 127.0.0.1:9090
# - Data persisted under /opt/nomad/data/grafana-data
# - Traefik tags for routing under /grafana via munchbox
# - Admin password injected securely from OpenBao/Vault
# -------------------------------------------------------------------------------

job "grafana" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  vault {
    policies = ["grafana-policy"]
  }

  group "grafana" {
    count = 1

    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    network {
      mode = "host"
      port "web" { static = 3000 }
    }

    task "grafana" {
      driver = "docker"

      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=PathPrefix(`/grafana`)",
          "traefik.http.routers.grafana.entrypoints=web",
          "traefik.http.services.grafana.loadbalancer.server.port=3000",
          "traefik.http.routers.grafana.middlewares=grafana-stripprefix@consulcatalog"
        ]

        check {
          name     = "grafana-alive"
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "grafana/grafana:10.4.2"
        ports              = ["web"]
        image_pull_timeout = "10m"

        volumes = [
          "local/grafana-provisioning:/etc/grafana/provisioning"
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/opt/nomad/data/grafana-data"
        read_only   = false
      }

      # Inject Grafana admin password from OpenBao/Vault using a template stanza
      template {
        data = <<EOH
GF_SECURITY_ADMIN_PASSWORD={{ with secret "kv/grafana" }}{{ .Data.admin_password }}{{ end }}
EOH
        destination = "secrets/grafana.env"
        env         = true
      }

      env = {
        GF_PATHS_DATA = "/opt/nomad/data/grafana-data"
        TZ            = "America/Los_Angeles"
      }

      resources {
        cpu    = 250
        memory = 512
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
