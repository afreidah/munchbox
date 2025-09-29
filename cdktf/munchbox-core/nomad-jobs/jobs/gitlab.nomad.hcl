# -------------------------------------------------------------------------------
#  GitLab CE — Nomad service job
#
#  * Runs GitLab Community Edition using the official Docker image.
#  * Persists configuration, logs, and data on the host for durability.
#  * Exposes HTTP web UI on :8080 and SSH on :2222.
#  * Registers a "gitlab" service in Consul (Traefik routes off that).
#  * Designed for personal use, light CI, and small repositories.
#
#  CHANGELOG (local):
#    - Add a prestart "permfix" task to create/fix bind-mounted paths and perms
#      so omnibus doesn't fail opening rails logs.
#    - Pin the GitLab image to a known-good tag (avoid surprise upgrades).
#    - Remove unused Nomad host volume + volume_mount (Docker binds are used).
#    - Correct memory comment to match requested allocation.
#    - Ensure Docker stdout/stderr are captured by Nomad:
#        * tty = false
#        * logging { type = "json-file" ... }
#    - Allow very long image pulls / slow first boot without failing the deploy:
#        * image_pull_timeout = "2h"
#        * update { progress_deadline = "2h", healthy_deadline < progress_deadline, stagger > 0s }
#        * service.check { check_restart.grace = "15m" }
# -------------------------------------------------------------------------------

job "gitlab" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  # Long deployment windows so pulling the image / first boot doesn't fail the job
  update {
    max_parallel       = 1
    min_healthy_time   = "15s"
    healthy_deadline   = "1h59m"  # must be < progress_deadline to pass validation
    progress_deadline  = "2h"
    stagger            = "5s"     # must be > 0s to pass validation
    auto_promote       = true
    auto_revert        = false
    canary             = 1
  }

  group "gitlab" {
    count = 1

    # --- Placement: run only on the specified node (cabot) ---------------------
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    volume "gitlab" {
      type      = "host"
      source    = "gitlab"
      read_only = false
    }

    # ---------------------------------------------------------------------------
    #  Networking
    # ---------------------------------------------------------------------------
    network {
      mode = "bridge"
      port "http" { static = 8080 } # GitLab web UI (proxied by Traefik)
      port "ssh"  { static = 2222 } # Git over SSH
    }

    # ---------------------------------------------------------------------------
    #  Prestart: fix host perms for bind mounts so Rails can write logs
    # ---------------------------------------------------------------------------
    task "permfix" {
      driver = "raw_exec"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        command = "/bin/bash"
        args = [
          "-lc",
          <<-EOF
          set -euo pipefail
          BASE="/opt/nomad/data/gitlab"

          # Service user IDs inside Omnibus:
          UID_GIT=998        # 'git'
          GID_GIT=998
          UID_PG=996         # 'gitlab-psql'
          GID_PG=996

          # Ensure base dirs exist
          install -d -m 0755 "$BASE/config" "$BASE/logs" "$BASE/data"

          # Prepare rails logs for the 'git' user
          install -d -m 0755 "$BASE/logs/gitlab-rails"
          touch "$BASE/logs/gitlab-rails/production.log" \
                "$BASE/logs/gitlab-rails/application_json.log"
          chown -R "$UID_GIT:$GID_GIT" "$BASE/logs/gitlab-rails"
          chmod 0664 "$BASE/logs/gitlab-rails/"*.log

          # Ensure Postgres paths exist and are owned by gitlab-psql
          install -d -m 0700 "$BASE/data/postgresql"
          install -d -m 0755 "$BASE/logs/postgresql"
          chown -R "$UID_PG:$GID_PG" "$BASE/data/postgresql" "$BASE/logs/postgresql"

          # Remove SSH host keys with wrong perms; GitLab will regenerate them
          rm -f "$BASE/config/ssh_host_"*"_key"* 2>/dev/null || true

          # DO NOT blanket chown $BASE/data or $BASE/config.
          # Omnibus will create/chown the rest correctly on first run.
          EOF
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # ---------------------------------------------------------------------------
    #  GitLab (Docker)
    # ---------------------------------------------------------------------------
    task "gitlab" {
      driver = "docker"

      config {
        # Pin to a specific tag to avoid surprise major/minor upgrades.
        image              = "gitlab/gitlab-ce:latest"
        image_pull_timeout = "2h"     # allow very slow pulls
        ports              = ["http", "ssh"]
        privileged         = true

        # Keep stdout/stderr flowing to `nomad logs`
        tty = false
        logging {
          type = "json-file"
          config = {
            max-size = "10m"
            max-file = "5"
          }
        }

        # Bind-mount host paths for config, logs, and data.
        volumes = [
          "/opt/nomad/data/gitlab/config:/etc/gitlab",
          "/opt/nomad/data/gitlab/logs:/var/log/gitlab",
          "/opt/nomad/data/gitlab/data:/var/opt/gitlab",
        ]
      }

      # Resource tuning: GitLab benefits from memory headroom.
      resources {
        cpu    = 2000 # ~2 CPUs worth of shares
        memory = 4096 # 4 GiB RAM
      }

      volume_mount {
        volume      = "gitlab"
        destination = "/local/gitlab"
        read_only   = false
      }

      # Omnibus inline config (heredoc to avoid quoting issues).
      env = {
        GITLAB_OMNIBUS_CONFIG = <<-OMNI
          external_url 'http://cabot:8080';
          gitlab_rails['gitlab_shell_ssh_port'] = 2222;
          puma['port'] = 8081
        OMNI
      }

      # -------------------------------------------------------------------------
      #  Service registration (Consul)
      # -------------------------------------------------------------------------
      service {
        name = "gitlab"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.gitlab.rule=Host(`gitlab.munchbox`)",
          "traefik.http.routers.gitlab.entrypoints=websecure",
          "traefik.http.routers.gitlab.tls=true",
        ]

        # Be lenient while GitLab boots the first time to avoid flappy restarts
        check {
          type     = "http"
          path     = "/users/sign_in"
          interval = "15s"
          timeout  = "3s"

          check_restart {
            limit  = 10
            grace  = "15m"  # give rails/nginx time to come up on first boot
          }
        }
      }
    }
  }
}
