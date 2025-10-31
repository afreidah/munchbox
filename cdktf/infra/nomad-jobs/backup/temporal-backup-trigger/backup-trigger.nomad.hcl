# ───────────────────────────────────────────────────────────────────────────────
# Temporal Backup Trigger — Nomad Periodic Batch Job
# ───────────────────────────────────────────────────────────────────────────────
#
# Initiates scheduled backups of HashiCorp infrastructure via Temporal workflows.
# Runs daily at 2:00 AM Pacific, triggering snapshots of Nomad, Consul, and
# OpenBao clusters. The actual backup execution is performed by the
# temporal-backup-worker service running on mccoy.
#
# Schedule: Daily at 2:00 AM PT (cron: "0 2 * * *")
# Binary: /usr/local/bin/temporal-backup-trigger (multi-arch: amd64 + arm64)
# Dependencies: temporal (server), temporal-backup-worker (executor)
#
# Manual execution: nomad job dispatch temporal-backup-trigger
# Monitor: Temporal UI at http://192.168.68.61:8080
# ───────────────────────────────────────────────────────────────────────────────

job "temporal-backup-trigger" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "all"

  # ─────────────────────────────────────────────────────────────────────────────
  # Schedule Configuration
  # ─────────────────────────────────────────────────────────────────────────────
  periodic {
    cron             = "0 2 * * *"
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Task Group
  # ─────────────────────────────────────────────────────────────────────────────
  group "trigger" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "host"
    }

    # ───────────────────────────────────────────────────────────────────────────
    # Trigger Task
    # ───────────────────────────────────────────────────────────────────────────
    task "trigger" {
      driver = "raw_exec"

      config {
        command = "/usr/local/bin/temporal-backup-trigger"
      }

      env {
        TEMPORAL_ADDRESS = "192.168.68.61:7233"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
