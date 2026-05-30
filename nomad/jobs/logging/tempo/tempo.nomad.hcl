# -------------------------------------------------------------------------------
# tempo — Munchbox Deployment
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job "tempo" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------


  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-02"
  }

  # ---------------------------------------------------------------------------
  # Task Group: tempo
  # ---------------------------------------------------------------------------

  group "tempo" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 3200
      }
      port "otlp-grpc" {
        static = 4317
      }
      port "otlp-http" {
        static = 4318
      }
      port "zipkin" {
        static = 9411
      }
      port "jaeger-http" {
        static = 14268
      }
      port "jaeger-grpc" {
        static = 14250
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }
    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "tempo"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.tempo.rule=Host(`tempo.munchbox`)",
        "traefik.http.routers.tempo.entrypoints=websecure",
        "traefik.http.routers.tempo.tls=true",
        "traefik.http.routers.tempo.middlewares=dashboard-allowlan@file",
        "traefik.http.services.tempo.loadbalancer.server.port=3200",
        "logging",
        "tempo",
        "tracing",
        "observability",
      ]
      check {
        name      = "tempo-health"
        type      = "http"
        path      = "/ready"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Init Task: Create local storage directory
    # -------------------------------------------------------------------------

    task "init-storage" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sh"
        args    = ["-c", "mkdir -p /init-data && chown -R 10001:10001 /init-data && chmod 755 /init-data"]
        volumes = [
          "/opt/nomad/data/tempo:/init-data"
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # -------------------------------------------------------------------------
    # Task: tempo
    # -------------------------------------------------------------------------

    task "tempo" {
      driver = "docker"
      config {
        image              = "grafana/tempo:2.10.2"
        image_pull_timeout = "10m"
        ports              = ["http", "otlp-grpc", "otlp-http", "zipkin", "jaeger-http", "jaeger-grpc"]
        network_mode       = "host"
        args               = ["-config.file=/etc/tempo/config.yaml"]
        volumes            = ["/opt/nomad/data/tempo:/var/tempo", "local/config.yaml:/etc/tempo/config.yaml:ro"]
      }
      env {
        TZ = "America/Los_Angeles"
      }
      template {
        data        = <<EOH
# Tempo Configuration
stream_over_http_enabled: true

server:
  http_listen_port: 3200
  grpc_listen_port: 9196  # historical: kept off 9095 (was promtail; now alloy)
  log_level: info

# Distributor receives traces from clients
distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    zipkin:
      endpoint: 0.0.0.0:9411
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
        grpc:
          endpoint: 0.0.0.0:14250

# Ingester writes traces to storage
ingester:
  max_block_duration: 5m

# Compactor manages trace data lifecycle
compactor:
  compaction:
    block_retention: 72h  # 3 day retention

# Storage configuration (local filesystem)
storage:
  trace:
    backend: local
    wal:
      path: /var/tempo/wal
    local:
      path: /var/tempo/blocks

# Metrics generator for RED metrics from traces
metrics_generator:
  traces_storage:
    path: /var/tempo/generator/traces
  registry:
    external_labels:
      source: tempo
    collection_interval: 15s
  processor:
    local_blocks:
      max_live_traces: 10000
      flush_check_period: 30s
      complete_block_timeout: 120s
    service_graphs:
      dimensions: [http.method, http.status_code]
      enable_client_server_prefix: true
      peer_attributes: [peer.service, db.name, net.peer.name, server.address]
    span_metrics:
      dimensions: [http.method, http.status_code]
      enable_target_info: true
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://prometheus.service.consul:9090/api/v1/write
        send_exemplars: true

# Query configuration
querier:
  max_concurrent_queries: 10

# Overrides for multi-tenant limits
overrides:
  defaults:
    metrics_generator:
      processors: [service-graphs, span-metrics, local-blocks]

EOH
        destination = "local/config.yaml"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu        = 800
        memory     = 1024
        memory_max = 2048
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
  meta = {
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "tempo"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
