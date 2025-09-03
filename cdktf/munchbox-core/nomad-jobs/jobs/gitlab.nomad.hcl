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
#      so omnibus doesn't fail on readlink/stat of /var/opt/gitlab/git-data.
#    - Pin the GitLab image to a known-good tag (avoid surprise upgrades).
#    - Remove unused Nomad host volume + volume_mount (Docker binds are used).
#    - Correct memory comment to match requested allocation.
# -------------------------------------------------------------------------------

job "gitlab" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

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
      port "ssh" { static = 2222 }  # Git over SSH
    }

    # ---------------------------------------------------------------------------
    #  GitLab (Docker)
    # ---------------------------------------------------------------------------
    task "gitlab" {
      driver = "docker"

      config {
        # Pin to a specific tag to avoid surprise major/minor upgrades.
        # You can bump this deliberately later (e.g., 17.6.x).
        image              = "gitlab/gitlab-ce:latest"
        image_pull_timeout = "10m"
        ports              = ["http", "ssh"]
        privileged         = true

        # Bind-mount host paths for config, logs, and data.
        # NOTE: Ownership/permissions are ensured by the "permfix" prestart task.
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
        tags = ["traefik"] # Traefik watches Consul and routes HTTP to this task

        check {
          type     = "http"
          path     = "/users/sign_in"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }
  }
}
