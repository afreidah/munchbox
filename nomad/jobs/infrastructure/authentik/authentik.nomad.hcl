# -------------------------------------------------------------------------------
# Authentik — Identity Provider and SSO Platform
#
# Project: Munchbox / Author: Alex Freidah
#
# Authentik provides centralized authentication with support for OIDC, SAML,
# LDAP, and forward auth. Enables social login (Google, GitHub) and user/group
# management with application-level access control. Integrates with Traefik
# via forward auth middleware.
# -------------------------------------------------------------------------------

job "authentik" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"

  # -------------------------------------------------------------------------
  # Placement
  # -------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "nomad-client-02"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: Server
  # ---------------------------------------------------------------------------

  group "server" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "bridge"
      port "http" {
        static = 9000
        to     = 9000
      }
      port "https" {
        static = 9443
        to     = 9443
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
    # Task: Authentik Server
    # -------------------------------------------------------------------------

    task "server" {
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
        image              = "ghcr.io/goauthentik/server:2024.10"
        image_pull_timeout = "10m"
        ports              = ["http", "https"]
        args               = ["server"]
        volumes            = [
          "/mnt/gdrive-secondary/authentik/media:/media",
          "/mnt/gdrive-secondary/authentik/templates:/templates",
        ]
      }

      # --- Service Registration ---
      service {
        name     = "authentik"
        port     = "http"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.authentik.rule=Host(`auth.munchbox.cc`)",
          "traefik.http.routers.authentik.entrypoints=websecure",
          "traefik.http.routers.authentik.tls=true",
          "traefik.http.routers.authentik.middlewares=dashboard-allowlan@file",
        ]

        check {
          name     = "authentik-health"
          type     = "http"
          path     = "/-/health/ready/"
          interval = "15s"
          timeout  = "5s"
        }
      }

      # --- Static Environment Variables ---
      env {
        AUTHENTIK_REDIS__HOST               = "redis-shared.service.consul"
        AUTHENTIK_REDIS__DB                 = "1"
        AUTHENTIK_ERROR_REPORTING__ENABLED  = "false"
        AUTHENTIK_DISABLE_UPDATE_CHECK      = "true"
        AUTHENTIK_DISABLE_STARTUP_ANALYTICS = "true"
      }

      # --- Dynamic Secrets from Vault ---
      template {
        data = <<EOH
AUTHENTIK_SECRET_KEY={{ with secret "secret/data/authentik" }}{{ .Data.data.secret_key }}{{ end }}
AUTHENTIK_POSTGRESQL__HOST={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_host }}{{ end }}
AUTHENTIK_POSTGRESQL__PORT={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_port }}{{ end }}
AUTHENTIK_POSTGRESQL__NAME={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_db }}{{ end }}
AUTHENTIK_POSTGRESQL__USER={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_user }}{{ end }}
AUTHENTIK_POSTGRESQL__PASSWORD={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_password }}{{ end }}
EOH
        destination = "secrets/env"
        env         = true
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 1024
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  # ---------------------------------------------------------------------------
  # Task Group: Worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "bridge"
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
    # Task: Authentik Worker
    # -------------------------------------------------------------------------

    task "worker" {
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
        image              = "ghcr.io/goauthentik/server:2024.10"
        image_pull_timeout = "10m"
        args               = ["worker"]
        volumes            = [
          "/mnt/gdrive-secondary/authentik/media:/media",
          "/mnt/gdrive-secondary/authentik/templates:/templates",
          "/mnt/gdrive-secondary/authentik/certs:/certs",
        ]
      }

      # --- Service Registration ---
      service {
        name     = "authentik-worker"
        provider = "consul"

        tags = [
          "traefik.enable=false",
        ]
      }

      # --- Static Environment Variables ---
      env {
        AUTHENTIK_REDIS__HOST               = "redis-shared.service.consul"
        AUTHENTIK_REDIS__DB                 = "1"
        AUTHENTIK_ERROR_REPORTING__ENABLED  = "false"
        AUTHENTIK_DISABLE_UPDATE_CHECK      = "true"
        AUTHENTIK_DISABLE_STARTUP_ANALYTICS = "true"
      }

      # --- Dynamic Secrets from Vault ---
      template {
        data = <<EOH
AUTHENTIK_SECRET_KEY={{ with secret "secret/data/authentik" }}{{ .Data.data.secret_key }}{{ end }}
AUTHENTIK_POSTGRESQL__HOST={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_host }}{{ end }}
AUTHENTIK_POSTGRESQL__PORT={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_port }}{{ end }}
AUTHENTIK_POSTGRESQL__NAME={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_db }}{{ end }}
AUTHENTIK_POSTGRESQL__USER={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_user }}{{ end }}
AUTHENTIK_POSTGRESQL__PASSWORD={{ with secret "secret/data/authentik" }}{{ .Data.data.postgres_password }}{{ end }}
EOH
        destination = "secrets/env"
        env         = true
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 1024
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
