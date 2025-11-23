# -------------------------------------------------------------------------------
#  GitHub Actions Runner — Ephemeral CI Execution Environment
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Provides scalable, isolated CI runners using myoung34/github-runner with
#  Debian Trixie and Node.js 20, backed by Vault workload identity for secure
#  PAT and repository access, with Docker socket passthrough for containerized
#  build execution and dynamic service discovery via Consul.
# -------------------------------------------------------------------------------

job "github-runner" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "all"

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  # ---------------------------------------------------------------------------
  #  Runner Group
  # ---------------------------------------------------------------------------

  group "runner" {
    count = 2

    # --- Network configuration ---
    network {
      mode = "host"
    }

    # --- Placement constraints ---
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "mccoy"
    }

    # --- Ephemeral storage ---
    ephemeral_disk {
      size    = 5000
      migrate = false
      sticky  = false
    }

    # --- Task restart behavior ---
    restart {
      attempts = 10
      interval = "10m"
      delay    = "30s"
      mode     = "delay"
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 5
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Runner Task
    # -----------------------------------------------------------------------

    task "runner" {
      driver = "docker"

      # --- Workload identity and secrets ---
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "nomad-workloads"
      }

      # --- Docker image configuration ---
      config {
        image              = "docker-mirror.service.consul:5000/github-runner-waypoint:latest"
        image_pull_timeout = "10m"
        network_mode       = "host"
        privileged         = true
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        # Remove entrypoint - let the image's default entrypoint handle it
      }

      # --- Service registration ---
      service {
        name     = "github-runner"
        provider = "consul"
        tags = [
          "ci",
          "github-actions",
          "runner",
          "nomad-${NOMAD_ALLOC_INDEX}"
        ]
      }

      # --- Runtime environment ---
      template {
        destination = "secrets/github.env"
        env         = true
        data        = <<-EOT
          <<INJECT:files/github.env>>
        EOT
      }

      env {
        TZ                   = "America/Los_Angeles"
        START_DOCKER_SERVICE = "false"
      }

      # --- Resource allocation ---
      resources {
        cpu    = 2000
        memory = 2048
      }

      # --- Termination configuration ---
      kill_timeout   = "120s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "10s"
    }
  }
}
