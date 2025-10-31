# ───────────────────────────────────────────────────────────────────────────────
# Temporal Backup Worker — Nomad Service Job
# ───────────────────────────────────────────────────────────────────────────────
#
# Long-running worker service that executes Temporal backup workflows. Listens
# on the backup-task-queue for workflow executions triggered by the periodic
# backup-trigger job. Performs snapshot operations for Nomad, Consul, and
# OpenBao clusters, storing backups on /mnt/gdrive with 7-day retention.
#
# Execution: Runs continuously on mccoy (has /mnt/gdrive access)
# Authentication: Uses Nomad workload identity to retrieve credentials from Vault
# Dependencies: temporal (server), Vault KV secrets at kv/data/backup-worker
#
# Vault secrets required:
#   - nomad_token: Nomad management token for snapshot operations
#   - consul_token: Consul token with snapshot permissions
#
# Monitor: Temporal UI at http://192.168.68.61:8080
# ───────────────────────────────────────────────────────────────────────────────

job "temporal-backup-worker" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # ─────────────────────────────────────────────────────────────────────────────
  # Node Placement
  # ─────────────────────────────────────────────────────────────────────────────
  constraint {
    attribute = "${node.unique.name}"
    value     = "mccoy"
  }

  # ─────────────────────────────────────────────────────────────────────────────
  # Worker Group
  # ─────────────────────────────────────────────────────────────────────────────
  group "worker" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      mode = "host"
    }

    # ───────────────────────────────────────────────────────────────────────────
    # Service Registration
    # ───────────────────────────────────────────────────────────────────────────
    service {
      name     = "temporal-backup-worker"
      provider = "consul"

      tags = [
        "temporal",
        "backup",
        "worker",
      ]
    }

    # ───────────────────────────────────────────────────────────────────────────
    # Worker Task
    # ───────────────────────────────────────────────────────────────────────────
    task "worker" {
      driver = "raw_exec"

      # Nomad workload identity for Vault authentication
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      config {
        command = "/usr/local/bin/temporal-backup-worker"
      }

      # Service connection configuration
      env {
        TEMPORAL_ADDRESS  = "192.168.68.61:7233"
        NOMAD_ADDR        = "https://${attr.unique.network.ip-address}:4646"
        NOMAD_SKIP_VERIFY = "true"
        CONSUL_HTTP_ADDR  = "${attr.unique.network.ip-address}:8500"
        BAO_ADDR          = "https://mccoy:8200"
        BAO_SKIP_VERIFY   = "true"
      }

      # Vault-templated credentials
      template {
        env         = true
        destination = "secrets/tokens.env"
        data        = <<EOH
{{ with secret "kv/data/backup-worker" -}}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
{{- end }}
EOH
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }
    }
  }
}
