# -----------------------------------------------------------------------------
# GitLab — Full Backup (standalone job; maintenance-mode wrapped)
#
# - Runs on: cabot (host running GitLab Omnibus container)
# - Schedule: daily 02:00 PT (no overlap)
# - Backup tool: `gitlab-backup create STRATEGY=copy` (inside GitLab container)
# - Output: /mnt/gdrive/gitlab-backups/<timestamp>/
# - Maintenance mode: enable before backup; always disable on exit (trap)
# - Container discovery:
#     • Consul KV override: system-snapshots/gitlab_container
#     • Fallback autodetect: gitlab/gitlab-ce or gitlab/gitlab-ee ancestor
# - Retention: prune backup directories older than N days (default 14; KV override)
#
# Notes:
# - No Nomad `template` stanzas; all KV reads are best-effort at runtime.
# - Heredoc is unquoted (<<-SCRIPT) and contains no `${...}` to avoid HCL interpolation.
# - Quoting for rails runner uses %q[] to avoid nested-quote breakage.
# -----------------------------------------------------------------------------

job "gitlab-full-backup" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "all"

  # ----- Schedule -----
  periodic {
    cron             = "0 2 * * *"                 # daily 02:00 PT
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # -----------------------------------------------------------------------------
  # Backup group (runs on cabot)
  # -----------------------------------------------------------------------------
  group "gitlab" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    task "gitlab-backup" {
      driver = "raw_exec"
      user   = "root"

      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }

      config {
        command = "/bin/bash"
        args = [
          "-lc",
          <<-SCRIPT
            set -eo pipefail

            # --- Defaults (KV can override at runtime; non-fatal if missing) -----
            # If Consul CLI exists and keys are present, use them; otherwise defaults apply.
            if command -v consul >/dev/null 2>&1; then
              A="$(consul kv get system-snapshots/consul_http_addr 2>/dev/null || true)"
              T="$(consul kv get system-snapshots/consul_http_token 2>/dev/null || true)"
              if [ "x$A" != "x" ]; then export CONSUL_HTTP_ADDR="$A"; fi
              if [ "x$T" != "x" ]; then export CONSUL_HTTP_TOKEN="$T"; fi
            fi

            # --- Paths / timestamp ------------------------------------------------
            BACKUP_DIR_BASE="/mnt/gdrive/gitlab-backups"
            TS="$(date +%Y%m%d%H%M%S)"
            OUT_DIR="$BACKUP_DIR_BASE/$TS"
            mkdir -p "$OUT_DIR"

            # --- Determine GitLab container (KV override => CE/EE autodetect) ----
            CID=""
            if command -v consul >/dev/null 2>&1; then
              CID="$(consul kv get system-snapshots/gitlab_container 2>/dev/null || true)"
            fi
            if [ "x$CID" = "x" ]; then
              CID="$(docker ps --filter 'ancestor=gitlab/gitlab-ce' --format '{{.Names}}' | head -n1)"
              if [ "x$CID" = "x" ]; then
                CID="$(docker ps --filter 'ancestor=gitlab/gitlab-ee' --format '{{.Names}}' | head -n1)"
              fi
            fi
            if [ "x$CID" = "x" ]; then
              echo "GitLab container not found"
              exit 1
            fi
            echo "Using GitLab container: $CID"

            # --- Preflight: ensure gitlab-backup exists ---------------------------
            docker exec -t "$CID" /bin/bash -lc 'command -v gitlab-backup >/dev/null' \
              || { echo "gitlab-backup not found inside container"; exit 1; }

            # --- Always disable maintenance on exit -------------------------------
            disable_mm() {
              echo "Disabling maintenance mode..."
              docker exec -t "$CID" /bin/bash -lc 'gitlab-rails runner -e production "ApplicationSetting.current.update!(maintenance_mode: false)"'
            }
            trap disable_mm EXIT

            # --- Enable maintenance mode with message -----------------------------
            echo "Enabling maintenance mode..."
            docker exec -t "$CID" /bin/bash -lc 'gitlab-rails runner -e production "ApplicationSetting.current.update!(maintenance_mode: true, maintenance_mode_message: %q[Nightly backup in progress])"'

            # --- Run full backup (STRATEGY=copy for coherent tar layout) ----------
            echo "Starting GitLab full backup..."
            docker exec -t "$CID" /bin/bash -lc 'gitlab-backup create STRATEGY=copy'

            # --- Copy resulting backup archives out (Omnibus default dir) ---------
            echo "Copying backup archives out..."
            docker cp "$CID:/var/opt/gitlab/backups/." "$OUT_DIR"

            # --- Retention pruning (default 14 days; KV override if present) ------
            RETENTION_DAYS="14"
            if command -v consul >/dev/null 2>&1; then
              RD="$(consul kv get system-snapshots/retention_days 2>/dev/null || true)"
              if [ "x$RD" != "x" ]; then RETENTION_DAYS="$RD"; fi
            fi
            find "$BACKUP_DIR_BASE" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -print -exec rm -rf {} +

            echo "GitLab backup complete: $OUT_DIR (retention $RETENTION_DAYS days)"
          SCRIPT
        ]
      }

      resources {
        cpu    = 200      # conservative bump for compression
        memory = 256      # adjust per dataset size
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }
}
