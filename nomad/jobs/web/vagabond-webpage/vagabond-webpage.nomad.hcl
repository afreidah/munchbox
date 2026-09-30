# -------------------------------------------------------------------------------
# vagabond-webpage -- Project documentation site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the Vagabond Hugo documentation site from a static nginx container.
# Public over HTTP via the Cloudflare tunnel (router vagabond-web, no auth);
# direct HTTPS is LAN-restricted by the dashboard-allowlan middleware.
# No Vault.
# -------------------------------------------------------------------------------

job "vagabond-webpage" {
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
  # Task Group: vagabond-webpage
  # ---------------------------------------------------------------------------

  group "vagabond-webpage" {
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
      name     = "vagabond-webpage"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "vagabond",
        "documentation",

        # --- HTTPS (direct, LAN-restricted) ---
        "traefik.enable=true",
        "traefik.http.routers.vagabond-webpage.rule=Host(`vagabond.munchbox.cc`)",
        "traefik.http.routers.vagabond-webpage.entrypoints=websecure",
        "traefik.http.routers.vagabond-webpage.tls=true",
        "traefik.http.routers.vagabond-webpage.middlewares=dashboard-allowlan@file",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.http.routers.vagabond-web.rule=Host(`vagabond.munchbox.cc`)",
        "traefik.http.routers.vagabond-web.entrypoints=web",
        "traefik.http.routers.vagabond-web.service=vagabond-webpage",
        "traefik.http.routers.vagabond-web.priority=100",
      ]

      check {
        name      = "vagabond-webpage-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: vagabond-webpage
    # -------------------------------------------------------------------------

    task "vagabond-webpage" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/vagabond-web:0.1.0"
        image_pull_timeout = "10m"
        ports              = ["http"]
        force_pull         = true
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
