# ───────────────────────────────────────────────────────────────────────────────
# Temporal Workflow Engine — Nomad Service Job
# ───────────────────────────────────────────────────────────────────────────────
#
# Orchestrates durable workflows for infrastructure automation and scheduled tasks.
# Three task groups provide complete Temporal stack: PostgreSQL backend, Temporal
# server (gRPC), and web UI. All services use host networking and are constrained
# to the stabler node for co-location and simplified connectivity.
#
# Components:
#   - PostgreSQL 15: Persistent storage for workflow state and history
#   - Temporal Server: Workflow orchestration engine (auto-setup mode)
#   - Temporal UI: Web interface for workflow monitoring and debugging
#
# Access: https://temporal.munchbox (via Traefik)
# gRPC endpoint: 192.168.68.61:7233
# Note: Auto-setup mode used for evaluation - not production-ready
# ───────────────────────────────────────────────────────────────────────────────

job "temporal" {
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # ─────────────────────────────────────────────────────────────────────────────
  # Node Placement
  # ─────────────────────────────────────────────────────────────────────────────
  constraint {
    attribute = "${node.unique.name}"
    value     = "stabler"
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # PostgreSQL Database
  # ─────────────────────────────────────────────────────────────────────────────
  group "database" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "host"
      port "db" {
        static = 5432
      }
    }

    volume "temporal-postgres-data" {
      type      = "host"
      source    = "temporal-postgres-data"
      read_only = false
    }

    service {
      name     = "temporal-postgres"
      provider = "consul"
      port     = "db"

      tags = [
        "temporal",
        "postgres",
        "database",
      ]
    }

    task "postgres" {
      driver = "docker"

      volume_mount {
        volume      = "temporal-postgres-data"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      config {
        image              = "postgres:15-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
      }

      env {
        TZ                = "UTC"
        POSTGRES_USER     = "temporal"
        POSTGRES_PASSWORD = "temporal"
        POSTGRES_DB       = "temporal"
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
      }
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Temporal Server
  # ─────────────────────────────────────────────────────────────────────────────
  group "temporal-server" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "host"
      port "frontend" {
        static = 7233
      }
    }

    service {
      name     = "temporal-frontend"
      provider = "consul"
      port     = "frontend"

      tags = [
        "temporal",
        "frontend",
        "grpc",
      ]
    }

    task "temporal" {
      driver = "docker"

      config {
        image              = "temporalio/auto-setup:1.25.0"
        image_pull_timeout = "10m"
        network_mode       = "host"
      }

      env {
        TZ             = "UTC"
        DB             = "postgres12_pgx"
        DB_PORT        = "5432"
        POSTGRES_USER  = "temporal"
        POSTGRES_PWD   = "temporal"
        POSTGRES_SEEDS = "localhost"
      }

      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }
    }
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Temporal Web UI
  # ─────────────────────────────────────────────────────────────────────────────
  group "temporal-ui" {
    count = 1

    restart {
      attempts = 5
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "host"
      port "http" {
        static = 8088
      }
    }

    service {
      name     = "temporal-ui"
      provider = "consul"
      port     = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.temporal-ui.rule=Host(`temporal.munchbox`)",
        "traefik.http.routers.temporal-ui.entrypoints=websecure",
        "traefik.http.routers.temporal-ui.tls=true",
        "traefik.http.services.temporal-ui.loadbalancer.server.port=8088",
        "prometheus.scrape=true",
        "prometheus.port=8088",
        "temporal",
        "ui",
        "monitoring",
      ]

      check {
        name     = "http-temporal-ui"
        type     = "http"
        path     = "/"
        port     = "http"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "ui" {
      driver = "docker"

      config {
        image              = "temporalio/ui:2.31.1"
        image_pull_timeout = "10m"
        network_mode       = "host"
      }

      env {
        TZ                            = "UTC"
        TEMPORAL_ADDRESS              = "192.168.68.61:7233"
        TEMPORAL_CORS_ORIGINS         = "http://192.168.68.61:8080"
        TEMPORAL_CSRF_COOKIE_INSECURE = "true"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }
  }
}
