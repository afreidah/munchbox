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
  node_pool   = "oracle"

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
    count = 1

    # Run on Oracle ARM nodes (exclude micro-tier nodes)
    constraint {
      attribute = "${meta.tier}"
      operator  = "!="
      value     = "micro"
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
        args     = ["-c", "pgrep -f forgejo-runner"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: forgejo-runner
    # -------------------------------------------------------------------------

    task "forgejo-runner" {
      driver = "docker"

      # Native image defaults to a non-root user that can't reach the host
      # Docker socket; run as root like the old act_runner image did.
      user = "root"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "code.forgejo.org/forgejo/runner:12.13.0"
        network_mode = "host"
        privileged   = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "local/config.yaml:/config.yaml:ro"
        ]

        # Native image has no auto-register entrypoint (unlike gitea/act_runner's
        # run.sh): register from the Vault token env if not yet registered, then daemon.
        command = "/bin/sh"
        args    = ["-c", "test -f /data/.runner || /bin/forgejo-runner register --no-interactive --config /config.yaml --instance $GITEA_INSTANCE_URL --token $GITEA_RUNNER_REGISTRATION_TOKEN --name $GITEA_RUNNER_NAME --labels $GITEA_RUNNER_LABELS; exec /bin/forgejo-runner daemon --config /config.yaml"]
      }

      # --- Runner Configuration ---
      template {
        data        = <<-EOF
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
    - "docker:docker://catthehacker/ubuntu:act-latest"
    - "ubuntu-latest:docker://catthehacker/ubuntu:act-latest"
    - "ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04"
    - "ops:docker://registry.munchbox.cc/ops-build-image:latest"

cache:
  enabled: true
  dir: /data/cache

container:
  network: host
  privileged: true
  options: "--dns=192.168.68.64 --dns=192.168.68.62"
  valid_volumes:
    - /var/run/docker.sock
  docker_host: unix:///var/run/docker.sock
EOF
        destination = "local/config.yaml"
      }

      # --- Registration Token from Vault ---
      # Use internal Forgejo address to bypass oauth2-proxy
      template {
        data        = <<-EOF
GITEA_INSTANCE_URL=http://{{ range service "forgejo" }}{{ .Address }}:{{ .Port }}{{ end }}
{{- with secret "secret/data/forgejo-runner" }}
GITEA_RUNNER_REGISTRATION_TOKEN={{ .Data.data.registration_token }}
{{- end }}
GITEA_RUNNER_NAME=munchbox-runner-{{ env "NOMAD_ALLOC_INDEX" }}
GITEA_RUNNER_LABELS=self-hosted:host,docker:docker://catthehacker/ubuntu:act-latest,ubuntu-latest:docker://catthehacker/ubuntu:act-latest,ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04,ops:docker://registry.munchbox.cc/ops-build-image:latest
EOF
        destination = "secrets/runner.env"
        env         = true
        # --- env consumed only at first-register; re-render must NOT bounce ---
        change_mode = "noop"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      kill_timeout = "60s"
    }
  }
}
