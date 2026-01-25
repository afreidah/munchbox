# -------------------------------------------------------------------------------
# Temporal Trivy Scan Trigger — Scheduled Vulnerability Scanner
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal Trivy scan workflow weekly.
# Scans all running container images in the cluster for vulnerabilities.
# -------------------------------------------------------------------------------

job "temporal-trivy-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Periodic Scheduling - Weekly on Sunday at 3 AM
  # ---------------------------------------------------------------------------

  periodic {
    cron             = "0 3 * * 0"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
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
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        WORKFLOW_NAME               = "trivy"
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
        OTEL_SERVICE_NAME           = "temporal-trivy-trigger"
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
    "pack.job"             = "temporal-trivy-trigger"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
