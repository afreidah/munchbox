# -------------------------------------------------------------------------------
# nginx-resume -- resume.alexfreidah.com static site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves resume.alexfreidah.com (and www) from a static nginx container. Public
# over HTTP via the Cloudflare tunnel (router resume-public: www redirect,
# security headers, rate limit); TLS terminates at Cloudflare, so Traefik only
# sees :80. No Vault.
# -------------------------------------------------------------------------------

job "nginx-resume" {
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
  constraint {
    attribute = meta.role
    operator  = "!="
    value     = "ingress"
  }
  # --- Keep off the GPU/media node (nomad-client-04) to spare its load ---
  constraint {
    attribute = meta.gpu
    operator  = "!="
    value     = "true"
  }

  # ---------------------------------------------------------------------------
  # Task Group: nginx-resume
  # ---------------------------------------------------------------------------

  group "nginx-resume" {
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
      name     = "nginx-resume"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "nginx",
        "static",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.enable=true",
        "traefik.http.routers.resume-public.rule=Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)",
        "traefik.http.routers.resume-public.entrypoints=web",
        "traefik.http.routers.resume-public.service=nginx-resume",
        "traefik.http.routers.resume-public.middlewares=redirect-resume-www@file,resume-sec@file,resume-ratelimit@file",
        "traefik.http.routers.resume-public.priority=100",
      ]

      check {
        name      = "nginx-resume-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: nginx-resume
    # -------------------------------------------------------------------------

    task "nginx-resume" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/alex-resume:v0.0.8"
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
