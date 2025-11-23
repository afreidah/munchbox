# -------------------------------------------------------------------------------
#  Health Checker — Internal Service Health Monitoring and Alerting
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Go-based health checker service that monitors k3s process and other cluster
#  services. Runs containerized on goren node with dbus socket binding for
#  system integration. Exposes HTTP health endpoint for Traefik INTERNAL-ONLY
#  access via health.munchbox.
# -------------------------------------------------------------------------------

job "health-checker" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "1.0.0"
    owner       = "alex.freidah"
    category    = "utility"
    tier        = "tier-2"
    environment = "production"
    description = "Health checker service for cluster monitoring"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Health Checker Group
  # ---------------------------------------------------------------------------

  group "app" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # --- Network configuration ---
    network {
      port "http" {
        static = 18080
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 2
      interval = "30s"
      delay    = "5s"
      mode     = "fail"
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Health Checker Task
    # -----------------------------------------------------------------------

    task "health-checker" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image = "docker-mirror.service.consul:5000/health-checker"
        ports = ["http"]
        volumes = [
          "/var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro"
        ]
        args = ["--service", "k3s", "--port", "18080", "--interval", "10"]
      }

      # --- Service registration ---
      service {
        name = "health-checker"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.health.rule=Host(`health.munchbox`)",
          "traefik.http.routers.health.entrypoints=websecure",
          "traefik.http.routers.health.tls=true",
          "traefik.http.routers.health.middlewares=dashboard-allowlan@file",
          "traefik.http.services.health.loadbalancer.server.port=18080",
          "traefik.http.services.health.loadbalancer.server.scheme=http",
          "traefik.http.services.health.loadbalancer.healthcheck.path=/health",
          "traefik.http.services.health.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.health.loadbalancer.healthcheck.timeout=5s",
          "go",
          "health",
          "monitoring"
        ]

        # --- Health check ---
        check {
          name     = "health-checker"
          type     = "http"
          path     = "/health"
          interval = "15s"
          timeout  = "3s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
