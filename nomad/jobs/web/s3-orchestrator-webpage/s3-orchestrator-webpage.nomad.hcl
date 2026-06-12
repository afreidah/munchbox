# -------------------------------------------------------------------------------
# s3-orchestrator-webpage -- Project documentation site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the s3-orchestrator Hugo documentation site from a static nginx
# container. Public over HTTP via the Cloudflare tunnel (router s3orch-web, no
# auth); direct HTTPS is LAN-restricted by the dashboard-allowlan middleware.
# No Vault.
# -------------------------------------------------------------------------------

job "s3-orchestrator-webpage" {
  region      = "global"
  datacenters = ["munchbox"]
  node_pool   = "all"
  type        = "service"
  priority    = 50

  meta = {
    project = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 1
    auto_promote      = true
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Constraints
  # ---------------------------------------------------------------------------

  constraint {
    operator = "distinct_hosts"
    value    = "true"
  }

  # ---------------------------------------------------------------------------
  # Task Group: s3-orchestrator-webpage
  # ---------------------------------------------------------------------------

  group "s3-orchestrator-webpage" {
    count = 3

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      dns {
        servers = ["${attr.unique.network.ip-address}"]
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -------------------------------------------------------------------------
    # Service
    # -------------------------------------------------------------------------

    service {
      name     = "s3-orchestrator-webpage"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "s3-orchestrator",
        "documentation",

        # --- HTTPS (direct, LAN-restricted) ---
        "traefik.enable=true",
        "traefik.http.routers.s3-orchestrator-webpage.rule=Host(`s3-orchestrator.munchbox.cc`)",
        "traefik.http.routers.s3-orchestrator-webpage.entrypoints=websecure",
        "traefik.http.routers.s3-orchestrator-webpage.tls=true",
        "traefik.http.routers.s3-orchestrator-webpage.middlewares=dashboard-allowlan@file",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.http.routers.s3orch-web.rule=Host(`s3-orchestrator.munchbox.cc`)",
        "traefik.http.routers.s3orch-web.entrypoints=web",
        "traefik.http.routers.s3orch-web.service=s3-orchestrator-webpage",
        "traefik.http.routers.s3orch-web.priority=100",
      ]

      check {
        name      = "s3-orchestrator-webpage-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: s3-orchestrator-webpage
    # -------------------------------------------------------------------------

    task "s3-orchestrator-webpage" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/s3-orchestrator-web:v0.61.1"
        image_pull_timeout = "10m"
        ports              = ["http"]
      }

      resources {
        cpu    = 50
        memory = 32
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
