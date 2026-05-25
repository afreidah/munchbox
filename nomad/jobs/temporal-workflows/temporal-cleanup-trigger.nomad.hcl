# -------------------------------------------------------------------------------
# Cleanup Trigger - Scheduled Orphaned Data Cleanup
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal cleanup workflow daily at 5 AM.
# Removes orphaned job data directories that no longer correspond to running
# allocations on Nomad client nodes.
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
  # Placement
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "set_contains_any"
    value     = "goren,stabler"
  }

  # ---------------------------------------------------------------------------
  # Task Group: trigger
  # ---------------------------------------------------------------------------

  group "trigger" {
    count = 1

    network {
      mode = "host"
    }

    restart {
      attempts = 0
      mode     = "fail"
    }

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
        image              = "registry.munchbox.cc/backup-worker:v0.1.4"
        image_pull_timeout = "10m"
        entrypoint         = ["workflow-trigger"]
        network_mode       = "host"
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        WORKFLOW_NAME               = "cleanup"
        DRY_RUN                     = "false"
        GRACE_DAYS                  = "7"
        DOCKER_PRUNE                = "true"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      resources {
        cpu    = 50
        memory = 64
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
