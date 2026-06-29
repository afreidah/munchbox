# -------------------------------------------------------------------------------
# GitHub Actions Runner — moat (private repo)
#
# Project: Munchbox / Author: Alex Freidah
#
# Self-hosted GitHub Actions runners scoped to the private `moat` repo so its
# CI pipeline can run without burning paid hosted-runner minutes. Runs on the
# amd64 Proxmox VMs (nomad-client-0X) — moat's Packer/Kitchen/Cinc flows expect
# native amd64; the arm64 .deb is produced via goreleaser cross-compile.
#
# Registration token is fetched from Vault via workload identity (fine-grained
# PAT with Administration: Read+Write on the moat repo). Docker socket is
# mounted so workflow steps can build images and run containers.
# -------------------------------------------------------------------------------

job "github-runner-moat" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

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

  group "runner" {
    count = 2

    # these guys require a lot of resources so limit them to the heaviest nodes
    constraint {
      attribute = "nomad-client-04,nomad-client-05"
      operator  = "set_contains"
      value     = "${attr.unique.hostname}"
    }

    # Spread allocations across distinct hosts.
    constraint {
      distinct_hosts = true
    }

    network {
      mode = "host"
    }

    restart {
      attempts = 10
      interval = "10m"
      delay    = "30s"
      mode     = "delay"
    }

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = true
    }

    service {
      name     = "github-runner-moat"
      provider = "consul"
      task     = "runner"

      tags = [
        "ci",
        "github-actions",
        "runner",
        "moat"
      ]

      check {
        name     = "runner-alive"
        type     = "script"
        command  = "/bin/sh"
        args     = ["-c", "pgrep -f Runner.Listener || pgrep -f run.sh"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: runner
    # -------------------------------------------------------------------------

    task "runner" {
      driver = "docker"

      vault {
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image          = "registry.munchbox.cc/moat-runner-standard:1.0.3"
        privileged     = true
        cpu_hard_limit = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      env {
        TZ                   = "America/Los_Angeles"
        START_DOCKER_SERVICE = "false"
        RUN_AS_ROOT          = "false"
      }

      # --- Registration credentials from Vault ---
      template {
        data        = <<-EOF
{{- with secret "secret/data/github/moat-runner" }}
ACCESS_TOKEN="{{ .Data.data.token }}"
REPO_URL="{{ .Data.data.repo_url }}"
{{- if .Data.data.runner_group }}
RUNNER_GROUP="{{ .Data.data.runner_group }}"
{{- end }}
{{- end }}
RUNNER_NAME=moat-runner-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
RUNNER_SCOPE=repo
EPHEMERAL=true
LABELS=nomad,self-hosted,linux,x64,docker,moat
RUNNER_VERSION=latest
DISABLE_AUTO_UPDATE=true
EOF
        destination = "secrets/github.env"
        env         = true
        perms       = "0600"
        change_mode = "noop"
      }

      resources {
        cpu    = 6000
        memory = 2176
      }

      kill_timeout = "120s"
      kill_signal  = "SIGTERM"
    }
  }
}
