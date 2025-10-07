# -----------------------------------------------------------------------------
# backup-consul-snapshot — Standalone Consul snapshot job (Nomad batch)
# - Schedule: daily 02:00 PT
# - Target node: stabler
# - Output dir: /mnt/gdrive/consul-snapshots (mkdir -p)
#
# Vault secret path: kv/data/consul-snapshot
#   Required fields:
#     - consul_http_token: Consul ACL token
#   Optional fields:
#     - consul_http_addr: Consul address (default: http://127.0.0.1:8500)
#     - consul_ca_pem: CA certificate for HTTPS
#
# Requirements on target host:
#   - raw_exec driver enabled
#   - CLI installed: consul
#   - /mnt/gdrive/consul-snapshots reachable (job will mkdir -p)
# -----------------------------------------------------------------------------
job "backup-consul-snapshot" {
  region      = "global"  # [scope] single region batch
  datacenters = ["pi-dc"] # [placement] same DC as your cluster
  type        = "batch"   # [mode] periodic batch job
  node_pool   = "all"     # [pool] use pool with stabler

  # ----- Schedule -----
  periodic {
    cron             = "0 2 * * *"           # [when] daily at 02:00 PT
    prohibit_overlap = true                  # [safety] no overlapping runs
    time_zone        = "America/Los_Angeles" # [tz] schedule in PT
  }

  # ----- Placement: run on stabler only -----
  group "consul" {
    count = 1

    constraint {
      attribute = "$${node.unique.name}" # [nomad interp] escaped for Terraform
      operator  = "="
      value     = "stabler"
    }

    task "consul-snapshot" {
      driver = "raw_exec"
      user   = "root" # [fs perms] write under /mnt/gdrive

      # ----- Vault Workload Identity -----
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      # ----- Inject configuration from Vault into env/files -----
      template {
        destination = "local/env/consul.env"
        env         = true
        change_mode = "restart"
        data        = <<-EOT
{{ with secret "kv/data/consul-snapshot" }}
CONSUL_HTTP_ADDR={{ if .Data.data.consul_http_addr }}{{ .Data.data.consul_http_addr }}{{ else }}http://127.0.0.1:8500{{ end }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_http_token }}
{{ end }}
        EOT
      }

      template {
        destination = "secrets/consul-ca.pem"
        change_mode = "restart"
        data        = <<-EOT
{{ with secret "kv/data/consul-snapshot" }}{{ if .Data.data.consul_ca_pem }}{{ .Data.data.consul_ca_pem }}{{ end }}{{ end }}
        EOT
      }

      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }

      # ----- Snapshot logic (robust SSL handling + retries) -----
      config {
        command = "/bin/bash"
        args = [
          "-lc",
          <<-EOS
            set -euo pipefail

            SNAP_DIR="/mnt/gdrive/consul-snapshots"        # [output] destination folder
            mkdir -p "$SNAP_DIR"

            # [ssl switch] set SSL variables only if using https://
            case "$CONSUL_HTTP_ADDR" in
              https://*)
                export CONSUL_HTTP_SSL=true
                if [ -s "$NOMAD_SECRETS_DIR/consul-ca.pem" ]; then
                  export CONSUL_CACERT="$NOMAD_SECRETS_DIR/consul-ca.pem"
                else
                  export CONSUL_HTTP_SSL_VERIFY=false
                fi
                ;;
            esac

            TS="$(date +%Y%m%d%H%M%S)"
            SNAP_FILE="$SNAP_DIR/consul-$TS.snap"

            # [retry] transient network or leader re-election blips
            attempt=0
            max_attempts=5
            backoff=3
            while true; do
              if consul snapshot save "$SNAP_FILE"; then
                echo "Consul snapshot saved: $SNAP_FILE"
                break
              fi
              attempt=$((attempt + 1))
              if [ $attempt -ge $max_attempts ]; then
                echo "ERROR: snapshot failed after $max_attempts attempts" >&2
                exit 1
              fi
              sleep $((backoff * attempt))
            done
          EOS
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }
}
