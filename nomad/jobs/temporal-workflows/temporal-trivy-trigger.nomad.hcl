# -------------------------------------------------------------------------------
# Trivy Scan Trigger - Scheduled Vulnerability Scanner
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal trivy scan workflow daily.
# Scans all running container images in the cluster for vulnerabilities.
# -------------------------------------------------------------------------------

job "temporal-trivy-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Periodic Scheduling - Daily at 3 AM
  # ---------------------------------------------------------------------------

  periodic {
    cron             = "0 3 * * *"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
  }

  # ---------------------------------------------------------------------------
  # Placement - bare metal nodes for reliable WAN access
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
        WORKFLOW_NAME               = "trivy"
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
