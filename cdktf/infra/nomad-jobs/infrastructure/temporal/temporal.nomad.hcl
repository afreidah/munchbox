# -------------------------------------------------------------------------------
#  Temporal Workflow Engine — Durable Workflow Orchestration Platform
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Complete Temporal stack for infrastructure automation and scheduled task
#  orchestration. Three task groups: PostgreSQL 15 backend, Temporal server
#  with gRPC API, and web UI for monitoring. All services co-located on stabler
#  node with host networking for simplified connectivity and performance.
# -------------------------------------------------------------------------------

job "temporal" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # --- Job metadata ---
  meta {
    version     = "1.25.0"
    owner       = "alex.freidah"
    category    = "development"
    tier        = "tier-2"
    environment = "production"
    description = "Temporal workflow orchestration engine with PostgreSQL backend"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # --- Job-level placement constraints ---
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }

  # ---------------------------------------------------------------------------
  #  PostgreSQL Database Group
  # ---------------------------------------------------------------------------

  group "database" {
    count = 1

    # --- Persistent database storage volume ---
    volume "temporal-postgres-data" {
      type      = "host"
      source    = "temporal-postgres-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "db" {
        static = 5432
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
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
    #  PostgreSQL Task
    # -----------------------------------------------------------------------

    task "postgres" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "postgres:15-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["db"]
      }

      # --- Database storage volume mount ---
      volume_mount {
        volume      = "temporal-postgres-data"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      # --- Runtime environment ---
      env {
        TZ                = "UTC"
        POSTGRES_USER     = "temporal"
        POSTGRES_PASSWORD = "temporal"
        POSTGRES_DB       = "temporal"
      }

      # --- Service registration ---
      service {
        name     = "temporal-postgres"
        port     = "db"
        provider = "consul"
        tags = [
          "temporal",
          "postgres",
          "database"
        ]
      }

      # --- Resource allocation ---
      resources {
        cpu        = 500
        memory     = 512
        memory_max = 1024
      }
    }
  }

  # ---------------------------------------------------------------------------
  #  Temporal Server Group
  # ---------------------------------------------------------------------------

  group "temporal-server" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
      port "frontend" {
        static = 7233
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
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
    #  Temporal Server Task
    # -----------------------------------------------------------------------

    task "temporal" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "temporalio/auto-setup:1.25.0"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["frontend"]
      }

      # --- Runtime environment ---
      env {
        TZ             = "UTC"
        DB             = "postgres12_pgx"
        DB_PORT        = "5432"
        POSTGRES_USER  = "temporal"
        POSTGRES_PWD   = "temporal"
        POSTGRES_SEEDS = "localhost"
      }

      # --- Service registration ---
      service {
        name     = "temporal-frontend"
        port     = "frontend"
        provider = "consul"
        tags = [
          "temporal",
          "frontend",
          "grpc"
        ]
      }

      # --- Resource allocation ---
      resources {
        cpu        = 1000
        memory     = 1024
        memory_max = 2048
      }
    }
  }

  # ---------------------------------------------------------------------------
  #  Temporal Web UI Group
  # ---------------------------------------------------------------------------

  group "temporal-ui" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 8088
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 5
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
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
    #  Temporal UI Task
    # -----------------------------------------------------------------------

    task "ui" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image              = "temporalio/ui:2.31.1"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["http"]
      }

      # --- Runtime environment ---
      env {
        TZ                            = "UTC"
        TEMPORAL_ADDRESS              = "192.168.68.61:7233"
        TEMPORAL_CORS_ORIGINS         = "http://192.168.68.61:8080"
        TEMPORAL_CSRF_COOKIE_INSECURE = "true"
      }

      # --- Service registration ---
      service {
        name     = "temporal-ui"
        port     = "http"
        provider = "consul"
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
          "monitoring"
        ]

        # --- UI health check ---
        check {
          name                   = "temporal-ui"
          type                   = "http"
          port                   = "http"
          path                   = "/"
          interval               = "30s"
          timeout                = "10s"
          success_before_passing = 2
        }
      }

      # --- Resource allocation ---
      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }
  }
}
