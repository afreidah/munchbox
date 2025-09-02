# -------------------------------------------------------------------------------
# GitLab CE — Nomad service job
#
# * Runs the GitLab Community Edition using the official Docker image.
# * Persists configuration, logs, and data on the host for durability.
# * Exposes HTTP web UI on port 8080 and SSH on port 2222.
# * Registers service with Consul and configures Traefik for HTTP routing.
# * Designed for personal use, light CI, and small repositories.
# -------------------------------------------------------------------------------

job "gitlab" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "gitlab" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    volume "gitlab" {
      type      = "host"
      source    = "gitlab"
      read_only = false
    }

    network {
      mode = "bridge"
      port "http" { static = 8080 }
      port "ssh"  { static = 2222 }
    }

    task "gitlab" {
      driver = "docker"

      config {
        image              = "gitlab/gitlab-ce:latest"
        image_pull_timeout = "10m"
        ports              = ["http", "ssh"]
        privileged         = true

        # Mount the host volume for all GitLab data
        volumes = [
          "local/gitlab/config:/etc/gitlab",
          "local/gitlab/logs:/var/log/gitlab",
          "local/gitlab/data:/var/opt/gitlab"
        ]
      }

      resources {
        cpu    = 2000 # 2 CPUs
        memory = 4096 # 4GB RAM
      }

      env = {
        GITLAB_OMNIBUS_CONFIG = "external_url 'http://192.168.68.61:8080'; gitlab_rails['gitlab_shell_ssh_port'] = 2222; puma['listen']='127.0.0.1'; puma['port']=18080;"
      }

      volume_mount {
        volume      = "gitlab"
        destination = "/local/gitlab"
        read_only   = false
      }

      service {
        name = "gitlab"
        port = "http"
        tags = ["traefik"]
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
