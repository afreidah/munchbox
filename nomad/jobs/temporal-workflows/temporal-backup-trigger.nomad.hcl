# -------------------------------------------------------------------------------
# Backup Trigger - Scheduled Workflow Initiator
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal backup workflow daily at 2 AM.
# Uses the workflow-trigger binary from the backup-worker image with OTel
# tracing so the workflow start appears as a root span in Tempo.
# -------------------------------------------------------------------------------

job "temporal-backup-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Periodic Scheduling
  # ---------------------------------------------------------------------------

  periodic {
    cron             = "0 1 * * *"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
  }

  # ---------------------------------------------------------------------------
  # Placement - bare metal nodes for reliable WAN access
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "set_contains_any"
    value     = "goren,stabler.munchbox.cc"
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
        WORKFLOW_NAME               = "backup"
        LOCAL_RETENTION_DAYS        = "7"
        S3_RETENTION_DAYS           = "30"
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
