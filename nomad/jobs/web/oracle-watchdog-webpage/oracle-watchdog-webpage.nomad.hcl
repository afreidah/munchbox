# -------------------------------------------------------------------------------
# oracle-watchdog-webpage -- Project documentation site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the oracle-watchdog Hugo documentation site from a static nginx
# container. Public over HTTP via the Cloudflare tunnel (router owdog-web, no
# auth); direct HTTPS is LAN-restricted by the dashboard-allowlan middleware.
# No Vault.
# -------------------------------------------------------------------------------

job "oracle-watchdog-webpage" {
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

  # ---------------------------------------------------------------------------
  # Task Group: oracle-watchdog-webpage
  # ---------------------------------------------------------------------------

  group "oracle-watchdog-webpage" {
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
      name     = "oracle-watchdog-webpage"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "oracle-watchdog",
        "documentation",

        # --- HTTPS (direct, LAN-restricted) ---
        "traefik.enable=true",
        "traefik.http.routers.oracle-watchdog-webpage.rule=Host(`oracle-watchdog.munchbox.cc`)",
        "traefik.http.routers.oracle-watchdog-webpage.entrypoints=websecure",
        "traefik.http.routers.oracle-watchdog-webpage.tls=true",
        "traefik.http.routers.oracle-watchdog-webpage.middlewares=dashboard-allowlan@file",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.http.routers.owdog-web.rule=Host(`oracle-watchdog.munchbox.cc`)",
        "traefik.http.routers.owdog-web.entrypoints=web",
        "traefik.http.routers.owdog-web.service=oracle-watchdog-webpage",
        "traefik.http.routers.owdog-web.priority=100",
      ]

      check {
        name      = "oracle-watchdog-webpage-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: oracle-watchdog-webpage
    # -------------------------------------------------------------------------

    task "oracle-watchdog-webpage" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/oracle-watchdog-web:v1.4.6"
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
