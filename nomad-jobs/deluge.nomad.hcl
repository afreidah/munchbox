###############################################################################
# Deluge BitTorrent Client — Nomad service job
#
# * Runs the Deluge BitTorrent client using the linuxserver/deluge image.
# * Persists configuration and downloads on the host.
# * Exposes web UI on port 8112.
# * Registers service with Consul and configures Traefik for HTTPS routing.
###############################################################################

job "deluge" {
  datacenters = ["pi-dc"] # Nomad datacenter(s) to run in
  type        = "service" # Service job type

  meta {
    run_uuid = "${uuidv4()}" # Unique run identifier
  }

  group "deluge" {

    network {
      mode = "host" # Use host networking for container

      port "web" { # Expose port 8112 for Deluge web UI
        static = 8112 # Static port mapping
      }
    }

    volume "shared-data" {
      type      = "host"
      source    = "shared-data"
      read_only = false
    }

    task "deluge" {
      driver = "docker" # Use Docker driver

      config {
        image = "linuxserver/deluge" # Deluge Docker image
        image_pull_timeout = "10m"   # Timeout for pulling image
        volumes = [
          "shared-data:/etc/pihole",
          "local/deluge-config:/config",   # Persistent config storage
          "local/downloads:/downloads"     # Downloaded files storage
        ]
      }

      env {
        PUID = "1000" # User ID for container
        PGID = "1000" # Group ID for container
        TZ   = "UTC"  # Timezone
      }

      service {
        name     = "deluge"   # Service name for Consul
        port     = "web"
        provider = "consul"   # Register with Consul

        tags = [
          "traefik.enable=true",                                         # Enable Traefik
          "traefik.http.routers.deluge.rule=Host(`deluge.alexanddakota.com`)", # Traefik routing rule
          "traefik.http.routers.deluge.entrypoints=https",               # Use HTTPS entrypoint
          "traefik.http.routers.deluge.tls=true",                        # Enable TLS
          "traefik.http.routers.deluge.tls.certresolver=dns",            # Use DNS cert resolver
          "traefik.http.services.deluge.loadbalancer.server.port=8112"   # Internal service port for Traefik
        ]

        check {
          type     = "http"   # HTTP health check
          path     = "/"      # Path to check
          interval = "10s"    # Check interval
          timeout  = "2s"     # Timeout for check
          port     = "web"     # Port to check
        }
      }

      resources {
        cpu    = 200   # CPU MHz
        memory = 256   # Memory MB
      }
    }
  }
}
