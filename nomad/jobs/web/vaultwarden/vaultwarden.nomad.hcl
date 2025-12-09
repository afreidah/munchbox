# -------------------------------------------------------------------------------
# Vaultwarden — Self-Hosted Password Manager
#
# Project: Munchbox / Author: Alex Freidah
#
# Vaultwarden provides a self-hosted password management solution compatible
# with Bitwarden clients. Stores encrypted vault data on gdrive-secondary
# shared storage with Traefik ingress for HTTPS access.
# -------------------------------------------------------------------------------

job "vaultwarden" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
    auto_revert      = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: Vaultwarden
  # ---------------------------------------------------------------------------

  group "vaultwarden" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
      port "websocket" {
        to = 3012
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = false
    }

    # -------------------------------------------------------------------------
    # Task: Vaultwarden
    # -------------------------------------------------------------------------

    task "vaultwarden" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      # --- Workload Identity ---
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Container Configuration ---
      config {
        image              = "vaultwarden/server:latest"
        image_pull_timeout = "10m"
        ports              = ["http"]
        volumes            = [
          "/mnt/gdrive-secondary/vaultwarden:/data",
        ]
      }

      # --- Service Registration ---
      service {
        name     = "vaultwarden"
        port     = "http"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.vaultwarden.rule=Host(`vaultwarden.munchbox.cc`)",
          "traefik.http.routers.vaultwarden.entrypoints=websecure",
          "traefik.http.routers.vaultwarden.tls=true",
          "traefik.http.routers.vaultwarden.middlewares=dashboard-allowlan@file",
          "traefik.http.routers.vaultwarden.service=vaultwarden",
          "traefik.http.routers.vaultwarden-ws.rule=Host(`vaultwarden.munchbox.cc`) && Path(`/notifications/hub`)",
          "traefik.http.routers.vaultwarden-ws.entrypoints=websecure",
          "traefik.http.routers.vaultwarden-ws.tls=true",
          "traefik.http.routers.vaultwarden-ws.middlewares=dashboard-allowlan@file",
          "traefik.http.routers.vaultwarden-ws.service=vaultwarden-ws",
          "traefik.http.routers.vaultwarden.middlewares=authentik@file"
        ]

        check {
          name     = "vaultwarden-health"
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # --- Environment Variables ---
      template {
        data        = <<-EOH
          {{ with secret "secret/data/vaultwarden" }}
          ADMIN_TOKEN={{ .Data.data.admin_token }}
          {{ end }}
          DOMAIN=https://vaultwarden.munchbox.cc
          SIGNUPS_ALLOWED=false
          INVITATIONS_ALLOWED=true
          WEBSOCKET_ENABLED=true
        EOH
        destination = "secrets/env"
        env         = true
        change_mode = "restart"
      }


      # --- Resources ---
      resources {
        cpu    = 250
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
