# -------------------------------------------------------------------------------
# Deluge BitTorrent Client — Nomad service job
#
# * Runs the Deluge BitTorrent client using the linuxserver/deluge image.
# * Persists configuration and downloads on the host.
# * Exposes web UI on port 8112.
# * Registers service with Consul and configures Traefik for HTTP routing.
# -------------------------------------------------------------------------------

job "deluge" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "deluge" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    volume "deluge-data" {
      type      = "host"
      source    = "deluge-data"
      read_only = false
    }

    network {
      mode = "host"
      port "web" { static = 8112 }
    }

    task "deluge" {
      driver = "docker"

      service {
        name     = "deluge"
        port     = "web"
        provider = "consul"

        check {
          name     = "deluge-alive"
          type     = "http"
          path     = "/"
          port     = "web"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "linuxserver/deluge"
        image_pull_timeout = "10m"
        ports              = ["web"]
        volumes = [
          "/opt/nomad/data/deluge-data/downloads:/downloads"
        ]
      }

      env = {
        PUID = "1000"
        PGID = "1000"
        TZ   = "UTC"
      }

      volume_mount {
        volume      = "deluge-data"
        destination = "/config"
        read_only   = false
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
