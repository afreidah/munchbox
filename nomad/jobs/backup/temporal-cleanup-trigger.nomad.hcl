# -------------------------------------------------------------------------------
# Temporal Cleanup Trigger — Scheduled Orphaned Data Cleanup
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal cleanup workflow weekly.
# Removes orphaned job data directories that no longer correspond to running
# allocations on the local node.
#
# By default runs in DRY_RUN mode - set DRY_RUN=false to actually delete.
# -------------------------------------------------------------------------------

job "temporal-cleanup-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 30

  # ---------------------------------------------------------------------------
  # Periodic Scheduling - Daily at 5 AM (after backups and trivy)
  # ---------------------------------------------------------------------------

  periodic {
    cron             = "0 5 * * *"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
  }

  # ---------------------------------------------------------------------------
  # Placement - require x86_64 nodes (image not built for ARM)
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "amd64"
  }

  # ---------------------------------------------------------------------------
  # Task Group: trigger
  # ---------------------------------------------------------------------------

  group "trigger" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
    }

    # --- Restart Policy ---
    restart {
      attempts = 0
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 0
      interval       = "1h"
      delay          = "5s"
      delay_function = "constant"
      unlimited      = false
    }

    # -------------------------------------------------------------------------
    # Task: trigger
    # -------------------------------------------------------------------------

    task "trigger" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/temporal-backup-worker:latest"
        image_pull_timeout = "10m"
        args               = ["trigger"]
        network_mode       = "host"
      }

      env {
        TEMPORAL_ADDRESS = "temporal-server.service.consul:7233"
        WORKFLOW_NAME    = "cleanup"
        # Cleanup configuration
        DRY_RUN          = "false"  # Actually delete orphaned directories
        GRACE_DAYS       = "7"      # Only delete directories older than 7 days
        DOCKER_PRUNE     = "true"   # Also prune unused Docker images
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
        OTEL_SERVICE_NAME           = "temporal-cleanup-trigger"
      }

      # --- Resources ---
      resources {
        cpu    = 50
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    managed_by = "nomad"
    project    = "munchbox"
  }
}
