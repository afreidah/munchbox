# -------------------------------------------------------------------------------
# Cinc Console -- Web UI for the Cinc Server
#
# Project: Munchbox / Author: Alex Freidah
#
# Browse and edit nodes, roles, environments, data bags and cookbooks on
# cinc-server.munchbox.cc. Signs every request with the server's webui key and
# the logged-in user's name, so the server applies that user's ACLs; logins are
# checked against the server's own /authenticate_user. LAN-only behind
# oauth2-proxy, since the webui key can act as any user.
# -------------------------------------------------------------------------------

job "cinc-console" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # --- Needs the LAN cinc-server and Vault; not on oracle ---
  constraint {
    attribute = "${meta.cloud}"
    operator  = "!="
    value     = "oracle"
  }

  # ---------------------------------------------------------------------------
  # Task Group
  # ---------------------------------------------------------------------------

  group "cinc-console" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        to = 3000
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service (Traefik, LAN-only behind oauth2-proxy) ---
    service {
      name     = "cinc-console"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.cinc-console.rule=Host(`cinc-console.munchbox.cc`)",
        "traefik.http.routers.cinc-console.entrypoints=websecure",
        "traefik.http.routers.cinc-console.tls=true",
        "traefik.http.routers.cinc-console.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.routers.cinc-console-http.rule=Host(`cinc-console.munchbox.cc`)",
        "traefik.http.routers.cinc-console-http.entrypoints=web",
        "traefik.http.routers.cinc-console-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
      ]

      check {
        name     = "cinc-console-health"
        type     = "http"
        path     = "/api/healthz"
        interval = "15s"
        timeout  = "5s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: cinc-console
    # -----------------------------------------------------------------------

    task "cinc-console" {
      driver = "docker"

      # --- Vault Integration (webui key, server cert, session secret) ---
      vault {
        role        = "cinc-console"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "ghcr.io/tas50/cinc-console:0.5.0"
        image_pull_timeout = "5m"
        ports              = ["http"]
      }

      # --- Published by cinc_server::publish from the server's own key ---
      secret "webui" {
        provider = "vault"
        path     = "secret/data/cinc-server/webui"
        config {
          engine = "kv_v2"
        }
      }

      # --- The server's self-signed cert ---
      secret "server_cert" {
        provider = "vault"
        path     = "secret/data/cinc-server/trusted-cert"
        config {
          engine = "kv_v2"
        }
      }

      secret "console" {
        provider = "vault"
        path     = "secret/data/cinc-console"
        config {
          engine = "kv_v2"
        }
      }

      # --- Environment ---
      env {
        CINC_SERVER_URL = "https://cinc-server.munchbox.cc"
        CINC_WEBUI_KEY  = "${secret.webui.private_key}"
        CINC_CA_CERT    = "${secret.server_cert.cert}"
        SESSION_SECRET  = "${secret.console.session_secret}"
        CINC_AUTH_ACTOR = "pivotal"
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
