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
        image   = "busybox:1.38.0"
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

      vault {
        role        = "tempo"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "grafana/tempo:3.0.2"
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
# Tempo Configuration (3.0 architecture: live-store + block-builder + backend-scheduler)
stream_over_http_enabled: true

# --- disable usage reporting (stops phone-home to stats.grafana.org) ---
usage_report:
  reporting_enabled: false

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

# Storage configuration (S3 via the s3-orchestrator virtual bucket, reached over
# HTTPS through Traefik at s3.munchbox.cc/tempo-traces -- LAN-only, no oauth2).
# HTTPS is deliberate: minio-go signs UNSIGNED-PAYLOAD over TLS (which the gateway
# accepts) but signed-streaming over plain HTTP (which it rejects). The WAL stays
# on local disk; flushed blocks live in object storage.
storage:
  trace:
    backend: s3
    s3:
      endpoint: s3.munchbox.cc
      bucket: tempo-traces
      access_key: "{{ with secret "secret/data/s3-bucket/tempo-traces" }}{{ .Data.data.access_key }}{{ end }}"
      secret_key: "{{ with secret "secret/data/s3-bucket/tempo-traces" }}{{ .Data.data.secret_key }}{{ end }}"
      insecure: false
      forcepathstyle: true
    wal:
      path: /var/tempo/wal

# Metrics generator for RED metrics from traces.
# 3.0: the traces_storage block + local_blocks processor are gone; the live-store
# now serves recent traces internally, so they are no longer configured here.
metrics_generator:
  registry:
    external_labels:
      source: tempo
    collection_interval: 15s
  processor:
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
  max_concurrent_queries: 4  # was 10; fewer concurrent queries -> lower peak memory

# Overrides. 3.0: retention and compaction live under defaults.compaction. The
# compactor enforces block_retention - with it disabled, blocks are never
# deleted, so leave compaction enabled.
overrides:
  defaults:
    # --- memory guards (root cause of the OOM kills): both of these are UNBOUNDED
    #     by default, so a trace/cardinality spike can grow RAM without limit ---
    ingestion:
      max_traces_per_user: 10000  # cap live-store traces held in memory
    compaction:
      block_retention: 720h  # 30 day retention
    metrics_generator:
      processors: [service-graphs, span-metrics]
      max_active_series: 100000  # ceiling on RED-metric cardinality memory

EOH
        destination = "local/config.yaml"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu        = 800
        memory     = 1024
        memory_max = 4096
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
