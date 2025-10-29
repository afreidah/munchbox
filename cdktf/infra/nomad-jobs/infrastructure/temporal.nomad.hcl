# -------------------------------------------------------------------------------
# Temporal Workflow Engine — Nomad service job
#
# - Runs Temporal Server with PostgreSQL backend for workflow orchestration
# - Three task groups: database, temporal-server, and temporal-ui
# - Uses Consul Connect for service mesh communication
# - Temporal UI exposed via Traefik for workflow monitoring
# - Auto-setup mode for evaluation (not production-ready)
# -------------------------------------------------------------------------------

job "temporal" {
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "database" {
    count = 1

    # Restart policy for database resilience
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "bridge"
      port "db" {
        to = 5432
      }
    }

    # --- Persistent storage for PostgreSQL data -------------------------------
    volume "temporal-postgres-data" {
      type      = "host"
      source    = "temporal-postgres-data"
      read_only = false
    }

    service {
      name     = "temporal-postgres"
      provider = "consul"
      port     = "db"

      connect {
        sidecar_service {}
      }

      check {
        name     = "tcp-postgres"
        type     = "tcp"
        port     = "db"
        interval = "10s"
        timeout  = "2s"
      }

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
        ports              = ["db"]
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

  group "temporal-server" {
    count = 1

    # Restart policy - higher attempts since it depends on database
    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "bridge"
      port "frontend" {
        to = 7233
      }
    }

    service {
      name     = "temporal-frontend"
      provider = "consul"
      port     = "frontend"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "temporal-postgres"
              local_bind_port  = 5432
            }
          }
        }
      }

      check {
        name     = "tcp-temporal-grpc"
        type     = "tcp"
        port     = "frontend"
        interval = "10s"
        timeout  = "2s"
      }

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
        ports              = ["frontend"]
      }

      env {
        TZ                       = "UTC"
        DB                       = "postgresql"
        DB_PORT                  = "5432"
        POSTGRES_USER            = "temporal"
        POSTGRES_PWD             = "temporal"
        POSTGRES_SEEDS           = "localhost"
        DYNAMIC_CONFIG_FILE_PATH = "/etc/temporal/config/dynamicconfig/development-sql.yaml"
      }

      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }
    }
  }

  group "temporal-ui" {
    count = 1

    # Restart policy for UI resilience
    restart {
      attempts = 5
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "bridge"
      port "http" {
        to = 8080
      }
    }

    service {
      name     = "temporal-ui"
      provider = "consul"
      port     = "http"

      tags = [
        "traefik.enable=true",

        # Router configuration - use Host rule for your environment
        "traefik.http.routers.temporal-ui.rule=Host(`temporal.service.consul`)",
        "traefik.http.routers.temporal-ui.entrypoints=web",

        # Explicit backend port
        "traefik.http.services.temporal-ui.loadbalancer.server.port=8080",

        # Optional: Prometheus metrics
        "prometheus.scrape=true",
        "prometheus.port=8080",

        # Metadata tags
        "temporal",
        "ui",
        "monitoring",
      ]

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "temporal-frontend"
              local_bind_port  = 7233
            }
          }
        }
      }

      check {
        name                   = "http-temporal-ui"
        type                   = "http"
        path                   = "/"
        port                   = "http"
        interval               = "15s"
        timeout                = "5s"
        success_before_passing = 2
      }
    }

    task "ui" {
      driver = "docker"

      config {
        image              = "temporalio/ui:2.31.1"
        image_pull_timeout = "10m"
        ports              = ["http"]
      }

      env {
        TZ                            = "UTC"
        TEMPORAL_ADDRESS              = "localhost:7233"
        TEMPORAL_CORS_ORIGINS         = "http://localhost:8080"
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
