# -------------------------------------------------------------------------------
# g3-webpage -- Project documentation site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the g3 Hugo documentation site from a static nginx container. Public
# over HTTP via the Cloudflare tunnel (router g3-web, no auth); direct HTTPS is
# LAN-restricted by the dashboard-allowlan middleware. No Vault.
# -------------------------------------------------------------------------------

job "g3-webpage" {
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
    attribute = "${meta.role}"
    operator  = "!="
    value     = "ingress"
  }
  # --- Keep off the GPU/media node (nomad-client-04) to spare its load ---
  constraint {
    attribute = "${meta.gpu}"
    operator  = "!="
    value     = "true"
  }

  # ---------------------------------------------------------------------------
  # Task Group: g3-webpage
  # ---------------------------------------------------------------------------

  group "g3-webpage" {
    count = 3

    network {
      mode = "bridge"
      port "http" {
        # nginx-unprivileged (g3-web v0.5.2+) listens on 8080, not 80.
        to = 8080
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
      name     = "g3-webpage"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "g3",
        "documentation",

        # --- HTTPS (direct, LAN-restricted) ---
        "traefik.enable=true",
        "traefik.http.routers.g3-webpage.rule=Host(`g3.munchbox.cc`)",
        "traefik.http.routers.g3-webpage.entrypoints=websecure",
        "traefik.http.routers.g3-webpage.tls=true",
        "traefik.http.routers.g3-webpage.middlewares=dashboard-allowlan@file",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.http.routers.g3-web.rule=Host(`g3.munchbox.cc`)",
        "traefik.http.routers.g3-web.entrypoints=web",
        "traefik.http.routers.g3-web.service=g3-webpage",
        "traefik.http.routers.g3-web.priority=100",
      ]

      check {
        name      = "g3-webpage-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: g3-webpage
    # -------------------------------------------------------------------------

    task "g3-webpage" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/g3-web:v0.5.6"
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
