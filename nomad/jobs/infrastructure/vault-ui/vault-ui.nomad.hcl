# -------------------------------------------------------------------------------
# Vault UI — Redirect to Built-in Vault Web Interface
#
# Project: Munchbox / Author: Alex Freidah
#
# Simple nginx redirect to the built-in Vault UI. The old djenriquez/vault-ui
# had critical vulnerabilities and is no longer maintained. HashiCorp Vault
# includes a built-in UI at /ui on the server itself.
# -------------------------------------------------------------------------------

job "vault-ui" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"

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

  # ---------------------------------------------------------------------------
  # Placement - pin to specific node
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    value     = "nomad-client-01"
  }

  # ---------------------------------------------------------------------------
  # Task Group: vault-ui
  # ---------------------------------------------------------------------------

  group "vault-ui" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 8280
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service Registration ---
    service {
      name     = "vault-ui"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router
        "traefik.http.routers.vault-ui.rule=Host(`vault-ui.munchbox.cc`)",
        "traefik.http.routers.vault-ui.entrypoints=websecure",
        "traefik.http.routers.vault-ui.tls=true",
        "traefik.http.routers.vault-ui.middlewares=oauth2-proxy@file",
        "traefik.http.services.vault-ui.loadbalancer.server.port=8280",
        # HTTP router for CF tunnel
        "traefik.http.routers.vault-ui-http.rule=Host(`vault-ui.munchbox.cc`)",
        "traefik.http.routers.vault-ui-http.entrypoints=web",
        "traefik.http.routers.vault-ui-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file",
        "vault-ui",
        "vault",
        "ui",
        "infrastructure"
      ]

      check {
        name     = "vault-ui-health"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: nginx redirect
    # -------------------------------------------------------------------------

    task "vault-ui" {
      driver = "docker"

      config {
        image              = "nginx:alpine"
        image_pull_timeout = "5m"
        network_mode       = "host"
        ports              = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]
      }

      # --- Nginx config for redirect ---
      template {
        destination = "local/default.conf"
        data        = <<-EOF
server {
    listen 8280;
    server_name _;

    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        return 302 https://vault.munchbox.cc:8200/ui$request_uri;
    }
}
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 50
        memory = 32
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    managed_by = "nomad"
    project    = "munchbox"
  }
}
