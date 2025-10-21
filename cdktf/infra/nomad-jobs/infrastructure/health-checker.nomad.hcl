# ------------------------------------------------------------------------------
# Health Checker — Go service (internal-only, Traefik on *.munchbox)
# ------------------------------------------------------------------------------
# What this job does
# - Runs a single containerized health-checker service.
# - Binds host /var/run/dbus into the container (matches docker run).
# - Publishes container port 8080 to the node on static port 18080.
# - Registers a Nomad service with Traefik labels for INTERNAL access only:
#     * Host: health.munchbox
#     * EntryPoint: websecure (TLS), LAN-only middleware.
# ------------------------------------------------------------------------------

job "health-checker" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "app" {
    count = 1

    # Ensure this job runs where the k3s process is running
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }


    # --------------------------------------------------------------------------
    # Networking — publish container :8080 to node :18080 (static)
    #   - Traefik will forward to this published node port.
    # --------------------------------------------------------------------------
    network {
      port "http" {
        static = 18080
      }
    }

    task "health-checker" {
      driver = "docker"

      config {
        image = "docker-mirror.service.consul:5000/health-checker"
        ports = ["http"]
        volumes = [
          "/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro"
        ]

        # Container logging via journald
        logging {
          type = "journald"
          config {
            tag = "health-checker"
          }
        }

        # Override ENTRYPOINT/CMD
        args = ["--service", "k3s", "--port", "18080", "--interval", "10"]
      }

      # ------------------------------------------------------------------------
      # Resources — adjust based on real usage
      # ------------------------------------------------------------------------
      resources {
        cpu    = 200
        memory = 128
      }

      # ------------------------------------------------------------------------
      # Service Registration — Traefik (INTERNAL ONLY) + health checks
      # ------------------------------------------------------------------------
      service {
        name = "health-checker"
        port = "http"

        # Nomad HTTP health check (container listens on 8080)
        check {
          type     = "http"
          path     = "/health"
          interval = "15s"
          timeout  = "3s"
        }

        tags = [
          "traefik.enable=true",

          # ------------------------- INTERNAL ROUTER ----------------------------
          # Internal-only DNS host
          "traefik.http.routers.health.rule=Host(`health.munchbox`)",
          "traefik.http.routers.health.entrypoints=websecure",
          "traefik.http.routers.health.tls=true",

          # Restrict internal router to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.health.middlewares=dashboard-allowlan@file",

          # ------------------------- SERVICE (BACKEND) --------------------------
          # Point Traefik at the Nomad-published *node* port
          "traefik.http.services.health.loadbalancer.server.port=18080",
          "traefik.http.services.health.loadbalancer.server.scheme=http",

          # Traefik's own active healthcheck against backend
          "traefik.http.services.health.loadbalancer.healthcheck.path=/health",
          "traefik.http.services.health.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.health.loadbalancer.healthcheck.timeout=5s",

          # ------------------------- METADATA -----------------------------------
          "go",
          "health",
          "monitoring"
        ]
      }

      # ------------------------------------------------------------------------
      # Restart policy — keep the service healthy
      # ------------------------------------------------------------------------
      restart {
        attempts = 2
        interval = "30s"
        delay    = "5s"
        mode     = "fail"
      }
    }
  }
}
