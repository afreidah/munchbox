# -------------------------------------------------------------------------------
# Trivy Server — Vulnerability Scanner Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs Trivy in server mode to handle concurrent vulnerability scan requests.
# Uses Redis as cache backend for the vulnerability database. Workers call this
# service via HTTP API instead of spawning CLI processes.
# -------------------------------------------------------------------------------

job "trivy-server" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: server
  # ---------------------------------------------------------------------------

  group "server" {
    count = 1


    network {
      port "http" {
        static = 4954
        to     = 4954
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    service {
      name     = "trivy-server"
      port     = "http"
      provider = "consul"

      tags = [
        "trivy",
        "scanner",
      ]

      check {
        name     = "http-health"
        type     = "http"
        path     = "/healthz"
        interval = "15s"
        timeout  = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: trivy-server
    # -------------------------------------------------------------------------

    task "trivy-server" {
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
        image              = "aquasec/trivy:0.68.2"
        image_pull_timeout = "10m"
        ports              = ["http"]
        args               = [
          "server",
          "--listen", "0.0.0.0:4954",
        ]
      }

      template {
        data = <<-EOF
        {{ with secret "secret/data/redis-shared" }}
        TRIVY_CACHE_BACKEND=redis://:{{ .Data.data.password }}@redis-primary.service.consul:6379
        {{ end }}
        EOF
        destination = "secrets/secrets.env"
        env         = true
      }

      resources {
        cpu    = 500
        memory = 512
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
