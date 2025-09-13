# -----------------------------------------------------------------------------
# backup-core-services — Nomad + Consul + GitLab backups (via Consul KV)
# - Schedule: daily 02:00 PT
# - Nomad snapshot on mccoy      -> /mnt/gdrive/nomad-snapshots
# - Consul snapshot on stabler   -> /mnt/gdrive/consul-snapshots
# - GitLab Omnibus on cabot      -> /mnt/gdrive/gitlab-snapshots/<timestamp>/
#
# Consul KV keys expected (create these):
#   system-snapshots/nomad_token
#   system-snapshots/consul_http_token
#   (optional) system-snapshots/nomad_addr          default http://mccoy:4646
#   (optional) system-snapshots/consul_http_addr    default http://127.0.0.1:8500
#   (optional) system-snapshots/gitlab_container    override autodetect
#
# Requirements on target hosts:
#   - raw_exec driver enabled
#   - CLIs installed: nomad, consul, docker, bash
#   - /mnt/gdrive/*-snapshots reachable (job will mkdir -p)
# -----------------------------------------------------------------------------

job "backup-core-services" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "all"

  # ----- Schedule -----
  periodic {
    cron             = "0 2 * * *"
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # -----------------------------------------------------------------------------
  # Nomad snapshot
  # -----------------------------------------------------------------------------
  group "nomad" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    task "nomad-snapshot" {
      driver = "raw_exec"
      user   = "root"

      # ----- Inject TLS bits from Consul KV into env and files -----
      # Create keys as needed:
      #   system-snapshots/nomad_addr         (e.g., https://mccoy:4646)  [optional]
      #   system-snapshots/nomad_ca_pem       (PEM contents of CA)        [optional]
      #   system-snapshots/nomad_token        (ACL token)                 [required]
      template {
        destination = "local/env/nomad.env"
        env         = true
        change_mode = "restart"
        data        = "NOMAD_ADDR={{ keyOrDefault \"system-snapshots/nomad_addr\" \"https://mccoy:4646\" }}\nNOMAD_TOKEN={{ key \"system-snapshots/nomad_token\" }}"
      }
      template {
        destination = "secrets/nomad-ca.pem"
        change_mode = "restart"
        data = "{{ keyOrDefault \"system-snapshots/nomad_ca_pem\" \"\" }}"
      }

      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      }

      config {
        command = "/bin/bash"
        args = [
          "-lc",
          "set -euo pipefail; SNAP_DIR=/mnt/gdrive/nomad-snapshots; mkdir -p \"$SNAP_DIR\"; if [ -s \"$NOMAD_SECRETS_DIR/nomad-ca.pem\" ]; then export NOMAD_CACERT=\"$NOMAD_SECRETS_DIR/nomad-ca.pem\"; else export NOMAD_SKIP_VERIFY=1; fi; TS=$(date +%Y%m%d%H%M%S); nomad operator snapshot save \"$SNAP_DIR/nomad-$TS.snap\"; echo \"Nomad snapshot saved: $SNAP_DIR/nomad-$TS.snap\""
        ]
      }

      resources {
				cpu = 50
				memory = 64
			}

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }

  # -----------------------------------------------------------------------------
  # Consul snapshot (runs on stabler)
  # -----------------------------------------------------------------------------
  group "consul" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    task "consul-snapshot" {
      driver = "raw_exec"
      user   = "root"

      # ----- Inject TLS bits from Consul KV into env and files -----
      # Create keys as needed:
      #   system-snapshots/consul_http_addr   (e.g., https://127.0.0.1:8501) [optional]
      #   system-snapshots/consul_ca_pem      (PEM contents of CA)           [optional]
      #   system-snapshots/consul_http_token  (ACL token)                    [required]
      template {
        destination = "local/env/consul.env"
        env         = true
        change_mode = "restart"
        data        = "CONSUL_HTTP_ADDR={{ keyOrDefault \"system-snapshots/consul_http_addr\" \"https://127.0.0.1:8501\" }}\nCONSUL_HTTP_TOKEN={{ key \"system-snapshots/consul_http_token\" }}"
      }

      template {
        destination = "secrets/consul-ca.pem"
        change_mode = "restart"
        data        = "{{ keyOrDefault \"system-snapshots/consul_ca_pem\" \"\" }}"
      }

      env {
        TZ   = "America/Los_Angeles"
        PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        CONSUL_HTTP_SSL = "true"
      }

      config {
        command = "/bin/bash"
        args = [
          "-lc",
          "set -euo pipefail; SNAP_DIR=/mnt/gdrive/consul-snapshots; mkdir -p \"$SNAP_DIR\"; if [ -s \"$NOMAD_SECRETS_DIR/consul-ca.pem\" ]; then export CONSUL_CACERT=\"$NOMAD_SECRETS_DIR/consul-ca.pem\"; else export CONSUL_HTTP_SSL_VERIFY=false; fi; TS=$(date +%Y%m%d%H%M%S); consul snapshot save \"$SNAP_DIR/consul-$TS.snap\"; echo \"Consul snapshot saved: $SNAP_DIR/consul-$TS.snap\""
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

  # -----------------------------------------------------------------------------
  # GitLab backup (runs on cabot)
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
          "set -euo pipefail; SNAP_DIR_BASE=/mnt/gdrive/gitlab-snapshots; TS=$(date +%Y%m%d%H%M%S); OUT_DIR=\"$SNAP_DIR_BASE/$TS\"; mkdir -p \"$OUT_DIR\"; CONSUL_HTTP_ADDR_KV=$(consul kv get system-snapshots/consul_http_addr 2>/dev/null || true); if [ -n \"$CONSUL_HTTP_ADDR_KV\" ]; then export CONSUL_HTTP_ADDR=\"$CONSUL_HTTP_ADDR_KV\"; else export CONSUL_HTTP_ADDR=\"http://127.0.0.1:8500\"; fi; CID_KV=$(consul kv get system-snapshots/gitlab_container 2>/dev/null || true); if [ -n \"$CID_KV\" ]; then CID=\"$CID_KV\"; else CID=$(docker ps --filter 'ancestor=gitlab/gitlab-ce' --format '{{.Names}}' | head -n1); fi; if [ -z \"$CID\" ]; then echo 'GitLab container not found'; exit 1; fi; echo \"Running gitlab-backup in $CID...\"; docker exec -t \"$CID\" gitlab-backup create STRATEGY=copy; echo 'Copying archives out...'; docker cp \"$CID:/var/opt/gitlab/backups/.\" \"$OUT_DIR\"; echo \"GitLab backup copied to $OUT_DIR\""
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }
}
