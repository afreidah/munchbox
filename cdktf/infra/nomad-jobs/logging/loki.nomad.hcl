# -------------------------------------------------------------------------------
# Loki — Nomad Job for centralized log aggregation
#
# - Receives logs from Promtail agents on all nodes
# - 5-day log retention
# - Persistent storage on cabot
# - Exposes HTTP API for Grafana queries
# -------------------------------------------------------------------------------

job "loki" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  # Job metadata
  meta {
    version     = "3.2.0"
    updated     = "2025-10-07"
    description = "Loki log aggregation server"
  }

  group "loki" {
    count = 1

    # Pin to cabot for persistent storage
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # Host volume for log storage
    volume "loki-data" {
      type      = "host"
      source    = "loki-data"
      read_only = false
    }

    # Network configuration
    network {
      mode = "host"

      port "http" {
        static = 3100 # Standard Loki port
      }

      port "grpc" {
        static = 9096 # gRPC port for distributor/querier
      }
    }

    # Restart policy
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # Update strategy
    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
    }

    # Prestart task to fix permissions
    task "prepare-storage" {
      driver = "docker"
      user   = "root"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:latest"
        command = "sh"
        args = [
          "-c",
          <<-EOT
            mkdir -p /loki/chunks /loki/rules /loki/tsdb-index \
                     /loki/tsdb-cache /loki/compactor
            chown -R 10001:10001 /loki
            chmod -R 775 /loki
            ls -la /loki
            echo 'Permissions fixed!'
          EOT
        ]
      }

      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    task "loki" {
      driver = "docker"

      config {
        image        = "grafana/loki:3.2.0"
        network_mode = "host"
        ports        = ["http", "grpc"]

        args = [
          "-config.file=/etc/loki/config.yaml",
        ]

        volumes = [
          "local/config:/etc/loki:ro",
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "loki"
          }
        }
      }

      # Mount persistent storage
      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      # Loki configuration
      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        data        = <<-YAML
# Loki Configuration
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

# Query limits
query_scheduler:
  max_outstanding_requests_per_tenant: 2048

querier:
  max_concurrent: 4

# Schema configuration
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

# Storage configuration
storage_config:
  tsdb_shipper:
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
  filesystem:
    directory: /loki/chunks

# Compactor for retention
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem

# Limits - 5 day retention
limits_config:
  volume_enabled: true
  retention_period: 120h  # 5 days
  max_query_lookback: 120h
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  per_stream_rate_limit: 5MB
  per_stream_rate_limit_burst: 15MB

# Table manager for cleanup
table_manager:
  retention_deletes_enabled: true
  retention_period: 120h

# Analytics disabled
analytics:
  reporting_enabled: false
YAML
      }

      # Consul service registration
      service {
        name     = "loki"
        port     = "http"
        provider = "consul"

        tags = [
          "traefik.enable=true",

          # Router configuration
          "traefik.http.routers.loki.rule=Host(`loki.munchbox`)",
          "traefik.http.routers.loki.entrypoints=websecure",
          "traefik.http.routers.loki.tls=true",

          # Security middleware - reference file provider
          "traefik.http.routers.loki.middlewares=dashboard-allowlan@file",

          # Explicit port for Consul discovery
          "traefik.http.services.loki.loadbalancer.server.port=3100",

          # Metadata tags
          "logging",
          "loki",
          "observability"
        ]

        # Health check
        check {
          name     = "loki-ready"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles"
      }

      # Resource allocation
      resources {
        cpu    = 500 # MHz
        memory = 512 # MB
      }

      # Lifecycle management
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
