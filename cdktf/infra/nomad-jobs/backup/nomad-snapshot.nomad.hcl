# -----------------------------------------------------------------------------
# backup-nomad-snapshot — Standalone Nomad snapshot job (Nomad batch)
# - Schedule: daily 02:00 PT
# - Target node: goren
# - Output dir: /mnt/gdrive/nomad-snapshots (mkdir -p)
#
# Consul KV keys expected (create these):
#   system-snapshots/nomad_token                  # [required] Nomad ACL token
#   (optional) system-snapshots/nomad_addr        # default https://mccoy:4646
#   (optional) system-snapshots/nomad_ca_pem      # PEM string for CA when using HTTPS
#
# Requirements on target host:
#   - raw_exec driver enabled
#   - CLI installed: nomad
#   - /mnt/gdrive/nomad-snapshots reachable (job will mkdir -p)
# -----------------------------------------------------------------------------
job "backup-nomad-snapshot" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "all"

  # ----- Schedule -----
  periodic {
    crons            = ["0 2 * * *"]
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # -----------------------------------------------------------------------------
  # Nomad snapshot
  # -----------------------------------------------------------------------------
  group "nomad" {
    count = 1

    # [placement] run on goren only (escape Nomad interp for Terraform)
    constraint {
      attribute = "$${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    task "nomad-snapshot" {
      driver = "raw_exec"
      user   = "root"

      # ----- Inject TLS bits from Consul KV into env and files -----
      # Keys:
      #   system-snapshots/nomad_addr         e.g., https://mccoy:4646 (optional)
      #   system-snapshots/nomad_ca_pem       PEM contents of CA (optional)
      #   system-snapshots/nomad_token        ACL token (required)
      template {
        destination = "local/env/nomad.env"
        env         = true
        change_mode = "restart"
        data        = <<-EOT
          NOMAD_ADDR={{ keyOrDefault "system-snapshots/nomad_addr" "https://mccoy:4646" }}
          NOMAD_TOKEN={{ key "system-snapshots/nomad_token" }}
        EOT
      }
      template {
        destination = "secrets/nomad-ca.pem"
        change_mode = "restart"
        data        = "{{ keyOrDefault \"system-snapshots/nomad_ca_pem\" \"\" }}"
      }

      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }

      # ----- Snapshot logic (robust TLS handling + retries) -----
      config {
        command = "/bin/bash"
        args = [
          "-lc",
          <<-EOS
            set -euo pipefail

            SNAP_DIR="/mnt/gdrive/nomad-snapshots"
            mkdir -p "$SNAP_DIR"

            # [tls handling] use CA if provided; else skip verify for HTTPS endpoints
            if [ -s "$NOMAD_SECRETS_DIR/nomad-ca.pem" ]; then
              export NOMAD_CACERT="$NOMAD_SECRETS_DIR/nomad-ca.pem"
              unset NOMAD_SKIP_VERIFY || true
            else
              case "$NOMAD_ADDR" in
                https://*) export NOMAD_SKIP_VERIFY=1 ;;
              esac
            fi

            TS="$(date +%Y%m%d%H%M%S)"
            SNAP_FILE="$SNAP_DIR/nomad-$TS.snap"

            # [retry] transient network/leader blips
            attempt=0
            max_attempts=5
            backoff=3
            while true; do
              if nomad operator snapshot save "$SNAP_FILE"; then
                echo "Nomad snapshot saved: $SNAP_FILE"
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
