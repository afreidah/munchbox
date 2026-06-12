# -------------------------------------------------------------------------------
# personal-site -- alexfreidah.com static site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves alexfreidah.com (and www) from a static container. Public over HTTP
# via the Cloudflare tunnel (router alex-web, resume-sec middleware); TLS
# terminates at Cloudflare, so Traefik only sees :80. No Vault.
# -------------------------------------------------------------------------------

job "personal-site" {
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
  # Task Group: personal-site
  # ---------------------------------------------------------------------------

  group "personal-site" {
    count = 3

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      dns {
        servers = ["192.168.68.62", "192.168.68.64"]
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
      name     = "personal-site"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "personal",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.enable=true",
        "traefik.http.routers.alex-web.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
        "traefik.http.routers.alex-web.entrypoints=web",
        "traefik.http.routers.alex-web.service=personal-site",
        "traefik.http.routers.alex-web.middlewares=resume-sec@file",
        "traefik.http.routers.alex-web.priority=101",
      ]

      check {
        name      = "personal-site-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: personal-site
    # -------------------------------------------------------------------------

    task "personal-site" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/personal-site:v0.0.5"
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
