# -------------------------------------------------------------------------------
# Registry GC Trigger - Scheduled Docker Registry Garbage-Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic batch job that triggers the Temporal RegistryGC workflow weekly
# at 02:00 PT on Sunday. The workflow scales the registry job to 0 for the
# duration of GC (a brief outage of registry.munchbox.cc — minutes), runs
# `registry garbage-collect` against the bind-mounted storage, then scales
# the registry back to 1.
#
# DRY_RUN starts as true so the first scheduled run reports what would be
# deleted without actually freeing space. Flip to false once the
# alloc-scaling sequence has been observed end-to-end.
# -------------------------------------------------------------------------------

job "temporal-registry-gc-trigger" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 30

  # ---------------------------------------------------------------------------
  # Periodic Scheduling - Weekly, Sunday 02:00 PT
  # ---------------------------------------------------------------------------
  # Sunday early morning is the lowest CI / aptly-publish activity window.
  # GC briefly takes registry.munchbox.cc offline (typically a few minutes).

  periodic {
    cron             = "0 2 * * 0"
    time_zone        = "America/Los_Angeles"
    prohibit_overlap = true
  }

  # ---------------------------------------------------------------------------
  # Placement
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
        WORKFLOW_NAME               = "registry-gc"
        REGISTRY_JOB_NAME           = "registry"
        REGISTRY_DATA_DIR           = "/mnt/gdrive/munchbox-data/registry"
        REGISTRY_IMAGE              = "registry:3"
        DRY_RUN                     = "true"
        DELETE_UNTAGGED             = "true"
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
