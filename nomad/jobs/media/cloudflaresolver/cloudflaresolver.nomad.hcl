# -------------------------------------------------------------------------------
# Byparr — Cloudflare Bypass Proxy
#
# Project: Munchbox / Author: Alex Freidah
#
# Headless-browser proxy that solves Cloudflare anti-bot challenges for indexers.
# Drop-in FlareSolverr replacement (same /v1 API, same port 8191) consumed by
# Prowlarr; FlareSolverr was abandoned upstream and carried unpatched CVEs.
# -------------------------------------------------------------------------------

job "cloudflaresolverr" {
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
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement — pinned to the GPU media node to co-locate with Prowlarr and the
  # rest of the *arr stack (not for GPU use; just to keep the scrape path local).
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.gpu}"
    operator  = "="
    value     = "true"
  }

  # ---------------------------------------------------------------------------
  # Task Group: solver
  # ---------------------------------------------------------------------------

  group "solver" {
    count = 1

    network {
      port "http" {
        static = 8191
        to     = 8191
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    service {
      name     = "cloudflaresolverr"
      port     = "http"
      provider = "consul"

      tags = [
        "flaresolverr",
        "byparr",
        "proxy",
      ]

      check {
        name     = "tcp-alive"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: byparr
    # -------------------------------------------------------------------------

    task "byparr" {
      driver = "docker"

      config {
        image              = "ghcr.io/thephaseless/byparr:3.0.4"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"

        # Chromium crashes on Docker's default 64 MiB /dev/shm; tmpfs, so this
        # costs nothing until a challenge is actively being solved.
        shm_size = 536870912
      }

      env {
        LOG_LEVEL = "info"
        TZ        = "America/Los_Angeles"
      }

      # Idles cheap and only balloons while solving a challenge (rare). Reserve
      # a small floor and let it burst via oversubscription instead of pinning a
      # full gig it almost never uses.
      resources {
        cpu        = 100
        memory     = 256
        memory_max = 1536
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
