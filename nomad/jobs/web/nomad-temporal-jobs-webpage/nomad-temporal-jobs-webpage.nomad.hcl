# -------------------------------------------------------------------------------
# nomad-temporal-jobs-webpage -- Project documentation site
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the nomad-temporal-jobs Hugo documentation site from a static nginx
# container. Public over HTTP via the Cloudflare tunnel (router ntj-web, no
# auth); direct HTTPS is LAN-restricted by the dashboard-allowlan middleware.
# Kept off the oracle nodes. No Vault.
# -------------------------------------------------------------------------------

job "nomad-temporal-jobs-webpage" {
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
    attribute = "${node.unique.name}"
    operator  = "!="
    value     = "oraclenode1"
  }
  constraint {
    attribute = "${node.unique.name}"
    operator  = "!="
    value     = "oraclenode2"
  }

  # ---------------------------------------------------------------------------
  # Task Group: nomad-temporal-jobs-webpage
  # ---------------------------------------------------------------------------

  group "nomad-temporal-jobs-webpage" {
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
      name     = "nomad-temporal-jobs-webpage"
      port     = "http"
      provider = "consul"

      tags = [
        "web",
        "nomad-temporal-jobs",
        "documentation",

        # --- HTTPS (direct, LAN-restricted) ---
        "traefik.enable=true",
        "traefik.http.routers.nomad-temporal-jobs-webpage.rule=Host(`nomad-temporal-jobs.munchbox.cc`)",
        "traefik.http.routers.nomad-temporal-jobs-webpage.entrypoints=websecure",
        "traefik.http.routers.nomad-temporal-jobs-webpage.tls=true",
        "traefik.http.routers.nomad-temporal-jobs-webpage.middlewares=dashboard-allowlan@file",

        # --- HTTP (public via Cloudflare tunnel) ---
        "traefik.http.routers.ntj-web.rule=Host(`nomad-temporal-jobs.munchbox.cc`)",
        "traefik.http.routers.ntj-web.entrypoints=web",
        "traefik.http.routers.ntj-web.service=nomad-temporal-jobs-webpage",
        "traefik.http.routers.ntj-web.priority=100",
      ]

      check {
        name      = "nomad-temporal-jobs-webpage-health"
        type      = "http"
        path      = "/"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: nomad-temporal-jobs-webpage
    # -------------------------------------------------------------------------

    task "nomad-temporal-jobs-webpage" {
      driver = "docker"

      config {
        image              = "registry.munchbox.cc/temporal-workers-web:latest"
        force_pull         = true
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
