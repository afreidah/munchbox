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
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
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
        image              = "vaultwarden/server:1.34.3"
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
          # --- HTTPS router for API (no Authentik - Vaultwarden handles auth) ---
          # Required for Bitwarden CLI, mobile apps, browser extensions
          "traefik.http.routers.vaultwarden-api.rule=Host(`vaultwarden.munchbox.cc`) && (PathPrefix(`/api`) || PathPrefix(`/identity`) || PathPrefix(`/icons`) || PathPrefix(`/notifications`))",
          "traefik.http.routers.vaultwarden-api.entrypoints=websecure",
          "traefik.http.routers.vaultwarden-api.tls=true",
          "traefik.http.routers.vaultwarden-api.tls.certresolver=letsencrypt",
          "traefik.http.routers.vaultwarden-api.priority=20",
          # --- HTTPS router for Web UI (with Authentik) ---
          "traefik.http.routers.vaultwarden.rule=Host(`vaultwarden.munchbox.cc`)",
          "traefik.http.routers.vaultwarden.entrypoints=websecure",
          "traefik.http.routers.vaultwarden.tls=true",
          "traefik.http.routers.vaultwarden.tls.certresolver=letsencrypt",
          "traefik.http.routers.vaultwarden.middlewares=oauth2-proxy@file",
          "traefik.http.routers.vaultwarden.priority=10",
          # --- HTTP router for API (Cloudflare tunnel, no Authentik) ---
          "traefik.http.routers.vaultwarden-api-http.rule=Host(`vaultwarden.munchbox.cc`) && (PathPrefix(`/api`) || PathPrefix(`/identity`) || PathPrefix(`/icons`) || PathPrefix(`/notifications`))",
          "traefik.http.routers.vaultwarden-api-http.entrypoints=web",
          "traefik.http.routers.vaultwarden-api-http.middlewares=cf-tunnel-https@file",
          "traefik.http.routers.vaultwarden-api-http.priority=20",
          # --- HTTP router for Web UI (Cloudflare tunnel, with Authentik) ---
          "traefik.http.routers.vaultwarden-http.rule=Host(`vaultwarden.munchbox.cc`)",
          "traefik.http.routers.vaultwarden-http.entrypoints=web",
          "traefik.http.routers.vaultwarden-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file",
          "traefik.http.routers.vaultwarden-http.priority=10"
        ]

        check {
          name     = "vaultwarden-health"
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # --- Vault Secrets (Nomad 1.11 secret block) ---
      secret "vaultwarden" {
        provider = "vault"
        path     = "secret/data/vaultwarden"
        config {
          engine = "kv_v2"
        }
      }

      # --- Environment Variables ---
      env {
        ADMIN_TOKEN         = "${secret.vaultwarden.admin_token}"
        SIGNUPS_ALLOWED     = "${secret.vaultwarden.signups_allowed}"
        DOMAIN              = "https://vaultwarden.munchbox.cc"
        INVITATIONS_ALLOWED = "true"
        WEBSOCKET_ENABLED   = "true"
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
