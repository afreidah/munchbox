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
  # Placement — home cluster only (Oracle has unreliable image pulls and the
  # vuln DB sync is bandwidth-heavy; previously fit only on home nodes by
  # accident of resource size, now needs an explicit exclusion).
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.cloud}"
    operator  = "!="
    value     = "oracle"
  }

  # Keep off the ingress nodes (don't compete with the DB/haproxy there).
  constraint {
    attribute = "${meta.role}"
    operator  = "!="
    value     = "ingress"
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
        name      = "http-health"
        type      = "http"
        path      = "/healthz"
        interval  = "15s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: trivy-server
    # -------------------------------------------------------------------------

    task "trivy-server" {
      driver = "docker"

      vault {
        role        = "trivy-server"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "aquasec/trivy:0.74.0"
        image_pull_timeout = "10m"
        ports              = ["http"]
        args = [
          "server",
          "--listen", "0.0.0.0:4954",
          # --- Bound the fanal blob cache. Redis runs maxmemory-policy
          # noeviction and shares that budget with forgejo's job queue, so an
          # unbounded never-expiring cache here would eventually make forgejo's
          # queue writes fail with OOM rather than evicting anything. ---
          "--cache-ttl", "168h",
        ]
      }

      template {
        data        = <<-EOF
        {{ with secret "secret/data/redis-shared" }}
        TRIVY_CACHE_BACKEND=redis://:{{ .Data.data.password }}@haproxy-redis.service.consul:6380
        {{ end }}
        EOF
        destination = "secrets/secrets.env"
        env         = true
      }

      # Vuln DB sync spikes well above steady-state (OOM-killed at 256).
      # Keeping memory at the historical 512 MiB; CPU was safely cut.
      resources {
        cpu    = 100
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
