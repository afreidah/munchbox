# TYPE: nomad
# -------------------------------------------------------------------------------
#  Temporal Backup Trigger — Daily Scheduled Backup Orchestration
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Initiates daily backups of HashiCorp infrastructure via Temporal workflows.
#  Runs daily at 2:00 AM Pacific, triggering snapshots of Nomad, Consul, and
#  OpenBao clusters executed by the temporal-backup-worker service on mccoy.
# -------------------------------------------------------------------------------

job "temporal-backup-trigger" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "all"

  # --- Periodic schedule configuration ---
  periodic {
    crons            = ["0 2 * * *"]
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # ---------------------------------------------------------------------------
  #  Trigger Group
  # ---------------------------------------------------------------------------

  group "trigger" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # -----------------------------------------------------------------------
    #  Backup Trigger Task
    # -----------------------------------------------------------------------

    task "trigger" {
      driver = "raw_exec"

      # --- Task configuration ---
      config {
        command = "/usr/local/bin/temporal-backup-trigger"
      }

      # --- Runtime environment ---
      env {
        TEMPORAL_ADDRESS = "temporal-server.service.consul:7233"
      }

      # --- Resource allocation ---
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
