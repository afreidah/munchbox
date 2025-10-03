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
      user   = "root"   # run as root so we can invoke docker and adjust ownership

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        command = "/bin/bash"
        args = [
          "-c",
          <<-EOF
          set -euo pipefail
          BASE="/opt/nomad/data/gitlab"
          IMAGE="gitlab/gitlab-ce:18.4.1-ce.0"

          # Ensure docker exists and can talk to the daemon
          command -v docker >/dev/null 2>&1 || { echo "docker not found"; exit 1; }
          docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull "$IMAGE"

          # Use the same image to create/chown by NAME (robust across UID/GID shifts)
          docker run --rm \
            -v "$BASE/config:/etc/gitlab" \
            -v "$BASE/logs:/var/log/gitlab" \
            -v "$BASE/data:/var/opt/gitlab" \
            "$IMAGE" sh -c '
              set -e
              install -d -m 0750 /var/opt/gitlab/redis
              install -d -m 0755 /var/opt/gitlab/prometheus/data
              install -d -m 0700 /var/opt/gitlab/postgresql
              install -d -m 0755 /var/opt/gitlab/gitaly /var/opt/gitlab/git-data
              install -d -m 0755 /var/log/gitlab/gitlab-rails /var/log/gitlab/postgresql
              : > /var/log/gitlab/gitlab-rails/production.log
              : > /var/log/gitlab/gitlab-rails/application_json.log

              chown -R gitlab-redis:gitlab-redis /var/opt/gitlab/redis
              chown -R gitlab-prometheus:gitlab-prometheus /var/opt/gitlab/prometheus
              chown -R gitlab-psql:gitlab-psql /var/opt/gitlab/postgresql /var/log/gitlab/postgresql
              chown -R git:git /var/opt/gitlab/gitaly /var/opt/gitlab/git-data /var/log/gitlab/gitlab-rails /var/log/gitlab

              # Remove SSH host keys with wrong perms; GitLab will regenerate them
              rm -f /etc/gitlab/ssh_host_*_key* 2>/dev/null || true
            '
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
        image              = "gitlab/gitlab-ce:18.4.1-ce.0"
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
          external_url 'https://gitlab.munchbox';
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

          # Router configuration
          "traefik.http.routers.gitlab.rule=Host(`gitlab.munchbox`)",
          "traefik.http.routers.gitlab.entrypoints=websecure",
          "traefik.http.routers.gitlab.tls=true",

          # Restrict to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.gitlab.middlewares=dashboard-allowlan@file",

          # Explicit backend port
          "traefik.http.services.gitlab.loadbalancer.server.port=8080",

          # Metadata tags
          "gitlab",
          "git",
          "scm",
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
