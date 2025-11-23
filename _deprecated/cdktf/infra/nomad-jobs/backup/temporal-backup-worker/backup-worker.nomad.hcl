# -------------------------------------------------------------------------------
#  Temporal Backup Worker — Long-Running Workflow Execution Service
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Executes Temporal backup workflows triggered by the backup-trigger job via
#  the backup-task-queue. Performs snapshot operations for Nomad, Consul, and
#  OpenBao, storing backups on /mnt/gdrive with 7-day retention. Requires Vault
#  credentials for cluster access and dedicated node placement on mccoy.
# -------------------------------------------------------------------------------

job "temporal-backup-worker" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # ---------------------------------------------------------------------------
  #  Worker Group
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
    }

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      value     = "mccoy"
    }

    # --- Task restart behavior ---
    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # -----------------------------------------------------------------------
    #  Backup Worker Task
    # -----------------------------------------------------------------------

    task "worker" {
      driver = "raw_exec"

      # --- Workload identity and secrets ---
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      # --- Task configuration ---
      config {
        command = "/usr/local/bin/temporal-backup-worker"
      }

      # --- Service registration ---
      service {
        name     = "temporal-backup-worker"
        provider = "consul"
        tags = [
          "temporal",
          "backup",
          "worker"
        ]
      }

      # --- Runtime environment ---
      env {
        TEMPORAL_ADDRESS  = "192.168.68.61:7233"
        NOMAD_ADDR        = "https://${attr.unique.network.ip-address}:4646"
        NOMAD_SKIP_VERIFY = "true"
        CONSUL_HTTP_ADDR  = "${attr.unique.network.ip-address}:8500"
        BAO_ADDR          = "https://mccoy:8200"
        BAO_SKIP_VERIFY   = "true"
      }

      template {
        destination = "secrets/tokens.env"
        env         = true
        data        = <<-EOH
{{ with secret "kv/data/backup-worker" -}}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
{{- end }}
EOH
      }

      # --- Resource allocation ---
      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }
  }
}
