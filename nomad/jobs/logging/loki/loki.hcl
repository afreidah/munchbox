# -------------------------------------------------------------------------------
# Loki — Centralized Log Aggregation — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Receives logs from Promtail agents on all nodes via push API.
# Maintains 5-day log retention with TSDB filesystem backend for persistence.
# Exposes HTTP API for Grafana log queries.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name        = "loki"
job_type        = "service"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "edge"
priority        = 50

job_description = "Loki centralized log aggregation with 5-day retention"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }
]

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "standard"
meta_profile       = "tier-1"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "medium"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

ports = [
  {
    name   = "http"
    static = 3100
    port   = 3100
  },
  {
    name   = "grpc"
    static = 9096
    port   = 9096
  }
]

# -----------------------------------------------------------------------
# Storage & Volumes
# -----------------------------------------------------------------------

volume = {
  name       = "loki-data"
  type       = "host"
  source     = "loki-data"
  read_only  = false
  mount_path = "/loki"
}

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "30s"
restart_mode     = "fail"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "loki"
  driver = "docker"

  config = {
    image        = "grafana/loki:3.3.1"
    network_mode = "host"
    ports        = ["http", "grpc"]
    args = [
      "-config.file=/etc/loki/config.yaml"
    ]
    volumes = [
      "local/config:/etc/loki:ro"
    ]
  }

  templates = [
    {
      destination = "local/config/config.yaml"
      change_mode = "restart"
      perms       = "0644"
      data        = <<-EOF
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

# Telemetry
analytics:
  reporting_enabled: false
EOF
    }
  ]

  env = {
    TZ = "America/Los_Angeles"
  }

  service = {
    name     = "loki"
    port     = "http"
    provider = "consul"
    tags = [
      "logging",
      "loki",
      "observability"
    ]
    checks = [
      {
        name     = "loki-ready"
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "3s"
      }
    ]
  }

  resources = {
    cpu    = 500
    memory = 512
  }

  kill_timeout = "30s"
  kill_signal  = "SIGTERM"

  restart = {
    attempts = 3
    interval = "5m"
    delay    = "30s"
    mode     = "fail"
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  medium = {
    cpu             = 500
    memory          = 512
    ephemeral_disk  = 1000
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  standard = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  tier-1 = {
    tier = "tier-1"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    max_reschedules = 3
    delay           = "5s"
    delay_function  = "exponential"
    unlimited       = false
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  host = {
    mode = "host"
  }
}
