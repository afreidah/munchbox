# -------------------------------------------------------------------------------
# GitLab Backup — Nomad batch job
#
# * Runs the GitLab backup process using the official Docker image.
# * Ensures backups are stored on a mounted Google Drive directory for durability.
# * Runs on the same node as the main GitLab service for consistent data access.
# * Uses the same persistent volumes and Omnibus config as the GitLab service.
# * Schedules daily backups at 3am.
# -------------------------------------------------------------------------------

job "gitlab-backup" {
  datacenters = ["pi-dc"]
  type        = "batch"

  # Ensure backup runs on the same node as GitLab
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "cabot"
  }

  periodic {
    cron               = "0 3 * * *" # Daily at 3am
    prohibit_overlap   = true
  }

  group "backup" {
    task "backup" {
      driver = "docker"

      env = {
        GITLAB_OMNIBUS_CONFIG = <<-OMNI
          external_url 'http://cabot:8080';
          gitlab_rails['gitlab_shell_ssh_port'] = 2222;
          puma['port'] = 8081
        OMNI
      }

      config {
        image   = "gitlab/gitlab-ce:latest"
        command = "/bin/bash"
        args    = ["-c", "gitlab-backup create"]
        volumes = [
          "/mnt/gdrive/gitlab-backups:/var/opt/gitlab/backups",
          "local/gitlab/config:/etc/gitlab",
          "local/gitlab/logs:/var/log/gitlab",
          "local/gitlab/data:/var/opt/gitlab"
        ]
      }

      resources {
        cpu    = 100
        memory = 256
      }

      volume_mount {
        volume      = "gitlab"
        destination = "/local/gitlab"
        read_only   = false
      }
    }

    volume "gitlab" {
      type      = "host"
      source    = "gitlab"
      read_only = false
    }
  }
}
