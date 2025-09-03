# -------------------------------------------------------------------------------
# GitLab Approve Users — Nomad batch job
#
# * Runs a one-off command to approve all pending GitLab users.
# * Uses the official GitLab Docker image and mounts the same volumes as the main job.
# * Runs on the same node as the main GitLab service for consistent data access.
# -------------------------------------------------------------------------------

job "gitlab-approve-users" {
  datacenters = ["pi-dc"]
  type = "batch"

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "stabler"
  }

  group "approve" {
    task "approve-users" {
      driver = "docker"

      config {
        image = "gitlab/gitlab-ce:latest"
        command = "/bin/bash"
        args = [
          "-c",
          "gitlab-rails runner \"User.where(state: 'blocked_pending_approval').update_all(state: 'active')\""
        ]
        volumes = [
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
