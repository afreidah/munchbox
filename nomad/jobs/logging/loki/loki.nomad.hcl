# -------------------------------------------------------------------------------
# Loki - Centralized Log Aggregation
#
# Project: Munchbox / Author: Alex Freidah
#
# Receives logs from the alloy agents on every node and stores them with local
# retention. The ruler evaluates the log-based alert rules and posts to
# alertmanager.
#
# The rules come from Consul KV under loki/alerts/, one key per group, managed
# by infrastructure/terragrunt/apps/loki-alerts/. consul-template rewrites the
# rendered file by rename, which orphans a single-file bind mount: the container
# keeps the inode it started with and never sees a new rule. The ruler reads
# them out of the task directory instead, which nomad mounts at /local, because
# a directory mount resolves per open(2).
# -------------------------------------------------------------------------------

job "loki" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # --- Storage is a host path, so the job stays on the node holding it ---
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-02"
  }

  group "loki" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 3100
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    service {
      name     = "loki"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.rule=Host(`loki.munchbox`)",
        "traefik.http.routers.loki.entrypoints=websecure",
        "traefik.http.routers.loki.tls=true",
        "traefik.http.routers.loki.middlewares=dashboard-allowlan@file",
        "traefik.http.services.loki.loadbalancer.server.port=3100",
        "logging",
        "loki",
        "observability",
      ]

      check {
        name      = "loki-health"
        type      = "http"
        path      = "/ready"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    task "loki" {
      driver = "docker"

      config {
        image              = "grafana/loki:3.7.3"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["-config.file=/etc/loki/config.yaml"]

        # --- The rules are read through /local, so they get no bind of their
        #     own; one would latch to the inode consul-template replaces. ---
        volumes = [
          "/opt/nomad/data/loki:/loki",
          "local/config.yaml:/etc/loki/config.yaml:ro",
        ]
      }

      env {
        TZ = "America/Los_Angeles"
      }

      template {
        data        = <<EOH
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

# Schema configuration (TSDB)
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

# Ingestion tuning
ingester:
  chunk_idle_period: 3m
  max_chunk_age: 1h
  chunk_target_size: 1572864    # 1.5 MB target before flushing
  wal:
    replay_memory_ceiling: 512MB

# Storage configuration
storage_config:
  tsdb_shipper:
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
  filesystem:
    directory: /loki/chunks

# Compactor (for retention)
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
  retention_period: 120h
  max_query_lookback: 120h
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  per_stream_rate_limit: 5MB
  per_stream_rate_limit_burst: 15MB
  max_streams_per_user: 10000

# Cleanup (legacy table manager for some scans)
table_manager:
  retention_deletes_enabled: true
  retention_period: 120h

# Ruler configuration for log-based alerting
ruler:
  storage:
    type: local
    local:
      # The task directory, which nomad mounts as a directory so a rule file
      # replaced by rename is visible; a single-file bind would not be.
      directory: /local
  rule_path: /loki/rules-temp
  # Rules arrive by consul-template rewriting the file underneath the ruler,
  # so the poll is what picks a change up and is declared rather than defaulted.
  poll_interval: 1m
  alertmanager_url: http://alertmanager.service.consul:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
  enable_alertmanager_v2: true

# Telemetry
analytics:
  reporting_enabled: false

# Tracing disabled - Loki 3.6.x has OTEL SDK schema version conflict bug
# Re-enable when fixed upstream (https://github.com/grafana/loki/issues/14269)
tracing:
  enabled: false
EOH
        destination = "local/config.yaml"
        change_mode = "restart"
      }

      # --- The ruler expects <directory>/<tenant>/, and single-tenant loki
      #     calls its tenant fake. change_mode is noop because the ruler polls. ---
      template {
        data        = <<EOH
# Loki Log-Based Alert Rules
# Sourced from Consul KV prefix `loki/alerts/`. One key per group; managed by
# infrastructure/terragrunt/apps/loki-alerts/. Edit a YAML file under
# _env_helpers/loki-alerts/groups/, `terragrunt apply`, consul-template
# re-renders this file and the ruler reloads it on its next poll (no nomad
# redeploy).

groups:
{{- range tree "loki/alerts" }}
{{ .Value -}}
{{ end }}
EOH
        destination = "local/fake/alert_rules.yaml"
        change_mode = "noop"
      }

      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 2048
      }
    }
  }
}
