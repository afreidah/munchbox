# -------------------------------------------------------------------------------
# Temporal Backup Trigger — Scheduled Workflow Initiator
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal backup workflow daily at 2 AM.
# Runs as a simple trigger that submits workflow execution to Temporal server.
# -------------------------------------------------------------------------------

job "temporal-backup-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------


  # ---------------------------------------------------------------------------
  # Periodic Scheduling
  # ---------------------------------------------------------------------------

  periodic {
    cron             = "0 2 * * *"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
  }

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------

  # No constraint - can run on any node

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
        dns_servers        = ["192.168.68.64", "192.168.68.62"]
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
        OTEL_SERVICE_NAME           = "temporal-backup-trigger"
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
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "temporal-backup-trigger"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
