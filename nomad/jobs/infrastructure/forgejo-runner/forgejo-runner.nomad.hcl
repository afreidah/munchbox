# -------------------------------------------------------------------------------
# Forgejo Actions Runner — CI/CD Pipeline Executor
#
# Project: Munchbox / Author: Alex Freidah
#
# Forgejo Actions runner (act_runner) executes GitHub Actions compatible
# workflows. Connects to Forgejo server to receive jobs. Requires Docker
# socket access for container-based actions.
# -------------------------------------------------------------------------------

job "forgejo-runner" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  # ---------------------------------------------------------------------------
  # Task Group
  # ---------------------------------------------------------------------------

  group "forgejo-runner" {
    count = 2

    # Run on large Oracle Cloud free tier nodes
    constraint {
      attribute = "${meta.cloud}"
      value     = "oracle"
    }

    constraint {
      attribute = "${meta.size}"
      value     = "large"
    }

    # Force allocations onto different nodes
    constraint {
      distinct_hosts = true
    }

    network {
      mode = "host"
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    service {
      name     = "forgejo-runner"
      provider = "consul"
      task     = "forgejo-runner"

      tags = [
        "ci",
        "forgejo-actions",
        "runner"
      ]

      check {
        name     = "runner-alive"
        type     = "script"
        command  = "/bin/sh"
        args     = ["-c", "pgrep -f act_runner"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: forgejo-runner
    # -------------------------------------------------------------------------

    task "forgejo-runner" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "gitea/act_runner:0.2.11"
        network_mode = "host"
        privileged   = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "local/config.yaml:/config.yaml:ro"
        ]

        # Use daemon mode with config file
        args = ["daemon", "--config", "/config.yaml"]
      }

      # --- Runner Configuration ---
      template {
        data = <<-EOF
log:
  level: info

runner:
  file: /data/.runner
  capacity: 1
  timeout: 3h
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "self-hosted:host"
    - "docker:docker://node:20-alpine"
    - "ubuntu-latest:docker://ubuntu:22.04"
    - "ubuntu-22.04:docker://ubuntu:22.04"

cache:
  enabled: true
  dir: /data/cache

container:
  network: host
  privileged: true
  options:
  valid_volumes:
    - /var/run/docker.sock
  docker_host: unix:///var/run/docker.sock
EOF
        destination = "local/config.yaml"
      }

      # --- Registration Token from Vault ---
      template {
        data = <<-EOF
{{- with service "forgejo" }}{{- with index . 0 }}
GITEA_INSTANCE_URL=http://{{ .Address }}:{{ .Port }}
{{- end }}{{- end }}
{{- with secret "secret/data/forgejo-runner" }}
GITEA_RUNNER_REGISTRATION_TOKEN={{ .Data.data.registration_token }}
{{- end }}
GITEA_RUNNER_NAME=munchbox-runner-{{ env "NOMAD_ALLOC_INDEX" }}
GITEA_RUNNER_LABELS=self-hosted:host,docker:docker://node:20-alpine,ubuntu-latest:docker://ubuntu:22.04,ubuntu-22.04:docker://ubuntu:22.04
EOF
        destination = "secrets/runner.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      kill_timeout = "60s"
    }
  }
}
