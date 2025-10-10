# -----------------------------------------------------------------------------
# backup-consul-snapshot — Standalone Consul snapshot job (Nomad batch)
# - Schedule: daily 02:00 PT
# - Target node: stabler
# - Output dir: /mnt/gdrive/consul-snapshots (mkdir -p)
#
# Vault (OpenBao) secret path: kv/data/consul-snapshot
#   Required fields:
#     - consul_http_token: Consul ACL token
#   Optional fields:
#     - consul_http_addr: Consul address (default: http://127.0.0.1:8500)
#     - consul_ca_pem: CA certificate for HTTPS (PEM)
#
# Logging strategy (raw_exec):
#   - Keep Nomad alloc logs with task-level 'logs { ... }' rotation.
#   - Forward ALL stdout/stderr to systemd-journald using systemd-cat
#     by duplicating output via: tee >(systemd-cat -t <tag>)
#
# Requirements on target host:
#   - raw_exec driver enabled
#   - CLI installed: consul
#   - systemd present (for journald/systemd-cat)
#   - /mnt/gdrive/consul-snapshots reachable (job will mkdir -p)
# -----------------------------------------------------------------------------
job "backup-consul-snapshot" {
  region      = "global"              # [scope] single region batch
  datacenters = ["pi-dc"]             # [placement] same DC as your cluster
  type        = "batch"               # [mode] periodic batch job
  node_pool   = "all"                 # [pool] use pool with 'stabler'

  # ----- Schedule (Periodic) --------------------------------------------------
  periodic {
    cron             = "0 2 * * *"           # [when] daily at 02:00 PT
    prohibit_overlap = true                  # [safety] no overlapping runs
    time_zone        = "America/Los_Angeles" # [tz] schedule in PT
  }

  # ----- Placement ------------------------------------------------------------
  group "consul" {
    count = 1

    constraint {
      attribute = "node.unique.name"   # literal attribute key
      operator  = "="
      value     = "stabler"
    }

    task "consul-snapshot" {
      driver = "raw_exec"
      user   = "root" # [fs perms] write under /mnt/gdrive

      # ----- Vault Workload Identity ------------------------------------------
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      # ----- Inject configuration from Vault into env --------------------------
      template {
        destination = "local/env/consul.env"
        env         = true
        change_mode = "restart"
        data        = <<-EOT
{{- with secret "kv/data/consul-snapshot" -}}
{{- $d := .Data.data -}}
CONSUL_HTTP_ADDR={{ or $d.consul_http_addr "http://127.0.0.1:8500" }}
CONSUL_HTTP_TOKEN={{ $d.consul_http_token }}
{{- end -}}
EOT
      }

      # ----- Optional: CA file (only if provided in Vault) ---------------------
      template {
        destination = "secrets/consul-ca.pem"
        change_mode = "restart"
        perms       = "0600"
        data        = <<-EOT
{{- with secret "kv/data/consul-snapshot" -}}
{{- with .Data.data.consul_ca_pem -}}
{{ . }}
{{- end -}}
{{- end -}}
EOT
      }

      # ----- Environment -------------------------------------------------------
      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }

      # ----- Snapshot logic (SSL handling + retries + journald forwarding) -----
      config {
        command = "/bin/bash"
        args = [
          "-lc",
          <<-EOS
            set -euo pipefail

            # [journald tag] used by systemd-cat for log stream identification
            LOGTAG="consul-snapshot"

            # [script body] wrap all output and duplicate to both Nomad alloc logs and journald
            {
              echo "[INFO] Starting Consul snapshot job at $(date -Is)"

              SNAP_DIR="/mnt/gdrive/consul-snapshots"  # [output] destination folder
              mkdir -p "$SNAP_DIR"

              # [ssl switch] set SSL variables only if using https://
              case "$${CONSUL_HTTP_ADDR:-}" in
                https://*)
                  export CONSUL_HTTP_SSL=true
                  if [ -s "$NOMAD_SECRETS_DIR/consul-ca.pem" ]; then
                    export CONSUL_CACERT="$NOMAD_SECRETS_DIR/consul-ca.pem"
                    echo "[INFO] Using provided Consul CA certificate"
                  else
                    export CONSUL_HTTP_SSL_VERIFY=false
                    echo "[WARN] No CA provided; disabling HTTPS verify"
                  fi
                  ;;
                *)
                  : # http (default) — no additional SSL env vars
                  ;;
              esac

              TS="$(date +%Y%m%d%H%M%S)"
              SNAP_FILE="$SNAP_DIR/consul-$TS.snap"

              # [retry] handle transient failures (network, leader re-election)
              attempt=0
              max_attempts=5
              backoff=3

              while true; do
                if consul snapshot save "$SNAP_FILE"; then
                  echo "[INFO] Consul snapshot saved: $SNAP_FILE"
                  break
                fi

                attempt=$((attempt + 1))
                if [ $attempt -ge $max_attempts ]; then
                  echo "[ERROR] snapshot failed after $max_attempts attempts" >&2
                  exit 1
                fi

                sleep_time=$((backoff * attempt))
                echo "[WARN] snapshot failed (attempt $attempt/$max_attempts), retrying in $${sleep_time}s ..."
                sleep "$sleep_time"
              done

              echo "[INFO] Consul snapshot job finished at $(date -Is)"
            } 2>&1 | tee >(systemd-cat -t "$LOGTAG")
          EOS
        ]
      }

      # ----- Resources & Restart Policy ---------------------------------------
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
