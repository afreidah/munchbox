###############################################################################
# Grafana — Nomad Job (with persistent volume under /opt/nomad/data)
#
# - Runs Grafana using the official Docker image
# - Persists all data under /var/lib/grafana at /opt/nomad/data/grafana on the host
# - Registers with Consul for service discovery
# - Routes via Traefik at http://grafana.lan
# - Uses bridge networking (default, sufficient for Grafana)
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
# 1) Make sure your Nomad client has this in /etc/nomad.d/client.hcl:
#
# client {
#   host_volume "grafana-data" {
#     path      = "/opt/nomad/data/grafana_data"
#     read_only = false
#   }
# }
#
# Then `sudo systemctl restart nomad` on each node.
# ──────────────────────────────────────────────────────────────────────────────

job "grafana" {
  datacenters = ["pi-dc"]
  type        = "service"

  meta {
    run_uuid = "${uuidv4()}"
  }

  group "grafana" {
    count = 1

    # constraint {
    #   attribute = "${node.class}"
    #   operator  = "="
    #   value     = "pi5"
    # }

    # ────────────────────────────────────────────────────────────────
    # Attach the host_volume declared in client.hcl
    # ────────────────────────────────────────────────────────────────
    volume "data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    # ────────────────────────────────────────────────────────────────
    # Bridge networking; expose only the Grafana web UI port (3000)
    # ────────────────────────────────────────────────────────────────
    network {
      port "web" { static = 3000 }
      mode = "bridge"
    }

    # ────────────────────────────────────────────────────────────────
    # Grafana Task
    # ────────────────────────────────────────────────────────────────
    task "grafana" {
      driver = "docker"

      # ────────────────────────────────────────────────────────────────
      # Register Grafana in Consul (with Traefik tags for routing)
      # ────────────────────────────────────────────────────────────────
      service {
        name     = "grafana"
        port     = "web"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.lan`)",
          "traefik.http.routers.grafana.entrypoints=web", # use "websecure" for HTTPS
          "traefik.http.services.grafana.loadbalancer.server.port=3000"
        ]

        check {
          name     = "grafana-http"
          type     = "http"
          path     = "/login"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image              = "grafana/grafana:latest"
        ports              = ["web"]
        image_pull_timeout = "10m"
      }

      env = {
        TZ = "America/Los_Angeles"
        # GF_SECURITY_ADMIN_PASSWORD = "changeme" # (optional) set admin password at boot
      }

      resources {
        cpu    = 200
        memory = 256
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/grafana"
        read_only   = false
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

