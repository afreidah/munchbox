# -------------------------------------------------------------------------------
# Deluge BitTorrent Client — Nomad service job
#
# * Runs the Deluge BitTorrent client using the linuxserver/deluge image.
# * Persists configuration and downloads on the host.
# * Exposes web UI on port 8112.
# * Registers service with Consul and configures Traefik for HTTP routing.
# * Routes all Deluge traffic through the WireGuard VPN by running as 'vpnmark'.
#   (Requires host policy routing to mark 'vpnmark' traffic for VPN.)
# -------------------------------------------------------------------------------

job "deluge" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "deluge" {
    count = 1

    # Ensure this job only runs on the node with the VPN (mccoy)
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
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
      # Run as the 'vpnmark' user so all traffic is routed via the VPN
      user = "vpnmark"
      driver = "docker"
    
      config {
        image              = "goren:5000/deluge-with-vpnmark:latest"
        image_pull_timeout = "10m"
        ports              = ["web"]

        readonly_rootfs = false
        cap_add = ["CHOWN","FOWNER"]

        volumes = [
          "/opt/nomad/data/deluge-data/downloads:/downloads",
          "/mnt/gdrive/nomad_deluge_downloads:/completed"
        ]
      }
    
      env = {
        PUID = "1000"
        PGID = "1000"
        TZ   = "UTC"
        DELUGE_MOVE_COMPLETED_PATH = "/completed"
        DELUGE_MOVE_COMPLETED = "true"
      }
    
      volume_mount {
        volume      = "deluge-data"
        destination = "/config"
        read_only   = false
      }

      service {
        name = "deluge"
        port = "web"
        tags = ["traefik"]
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
