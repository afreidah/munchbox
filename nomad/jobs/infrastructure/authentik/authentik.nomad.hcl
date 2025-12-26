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

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
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

    # --- Placement: Pin to stabler ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler.munchbox.cc"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9000
      }
      port "https" {
        static = 9443
      }
      port "metrics" {
        static = 9300
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

    # --- Service Registration ---
    service {
      name     = "authentik"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router (for direct LAN access)
        "traefik.http.routers.authentik.rule=Host(`auth.munchbox.cc`)",
        "traefik.http.routers.authentik.entrypoints=websecure",
        "traefik.http.routers.authentik.tls=true",
        "traefik.http.routers.authentik.tls.certresolver=letsencrypt",
        # HTTP router (for Cloudflare tunnel - TLS terminated at CF edge)
        "traefik.http.routers.authentik-http.rule=Host(`auth.munchbox.cc`)",
        "traefik.http.routers.authentik-http.entrypoints=web",
        "traefik.http.routers.authentik-http.middlewares=cf-tunnel-https@file",
        "traefik.http.routers.authentik-http.service=authentik"
      ]

      check {
        name     = "authentik-health"
        type     = "http"
        path     = "/-/health/ready/"
        interval = "30s"
        timeout  = "10s"
        failures_before_critical = 3
      }

      deregister_critical_service_after = "1m"
    }

    # --- Metrics Service (for Prometheus) ---
    service {
      name     = "authentik-metrics"
      port     = "metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "prometheus",
        "metrics"
      ]

      check {
        name     = "authentik-metrics-health"
        type     = "http"
        port     = "metrics"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
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
        image              = "ghcr.io/goauthentik/server:2025.10.2"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["http", "https"]
        args               = ["server"]
        volumes            = [
          "/mnt/gdrive-secondary/authentik/media:/media",
          "/mnt/gdrive-secondary/authentik/templates:/templates",
        ]
      }

      # --- Vault Secrets (Nomad 1.11 secret block) ---
      secret "authentik" {
        provider = "vault"
        path     = "secret/data/authentik"
        config {
          engine = "kv_v2"
        }
      }

      secret "redis_shared" {
        provider = "vault"
        path     = "secret/data/redis-shared"
        config {
          engine = "kv_v2"
        }
      }

      # --- Environment Variables (static + dynamic from Vault) ---
      env {
        # Static config
        AUTHENTIK_REDIS__HOST                 = "redis-primary.service.consul"
        AUTHENTIK_REDIS__DB                   = "1"
        AUTHENTIK_ERROR_REPORTING__ENABLED    = "false"
        AUTHENTIK_DISABLE_UPDATE_CHECK        = "true"
        AUTHENTIK_DISABLE_STARTUP_ANALYTICS   = "true"
        AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS = "172.26.64.0/18,192.168.68.0/24,127.0.0.1/32"
        AUTHENTIK_HOST                        = "https://auth.munchbox.cc"
        AUTHENTIK_HOST_BROWSER                = "https://auth.munchbox.cc"
        # Note: Authentik does not yet support OTEL tracing (GitHub #12854)
        # Dynamic secrets from Vault
        AUTHENTIK_SECRET_KEY                  = "${secret.authentik.secret_key}"
        AUTHENTIK_POSTGRESQL__HOST            = "${secret.authentik.postgres_host}"
        AUTHENTIK_POSTGRESQL__PORT            = "${secret.authentik.postgres_port}"
        AUTHENTIK_POSTGRESQL__NAME            = "${secret.authentik.postgres_db}"
        AUTHENTIK_POSTGRESQL__USER            = "${secret.authentik.postgres_user}"
        AUTHENTIK_POSTGRESQL__PASSWORD        = "${secret.authentik.postgres_password}"
        AUTHENTIK_REDIS__PASSWORD             = "${secret.redis_shared.password}"
      }

      # --- Resources ---
      resources {
        cpu    = 2048
        memory = 2048
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

    # --- Placement: Pin to nomad-client-03 ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "nomad-client-03"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
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

    # --- Service Registration ---
    service {
      name     = "authentik-worker"
      provider = "consul"

      tags = [
        "traefik.enable=false",
      ]
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
        image              = "ghcr.io/goauthentik/server:2025.10.2"
        image_pull_timeout = "10m"
        network_mode       = "host"
        args               = ["worker"]
      }

      # --- Vault Secrets (Nomad 1.11 secret block) ---
      secret "authentik" {
        provider = "vault"
        path     = "secret/data/authentik"
        config {
          engine = "kv_v2"
        }
      }

      secret "redis_shared" {
        provider = "vault"
        path     = "secret/data/redis-shared"
        config {
          engine = "kv_v2"
        }
      }

      # --- Environment Variables (static + dynamic from Vault) ---
      env {
        # Static config
        AUTHENTIK_REDIS__HOST               = "redis-primary.service.consul"
        AUTHENTIK_REDIS__DB                 = "1"
        AUTHENTIK_ERROR_REPORTING__ENABLED  = "false"
        AUTHENTIK_DISABLE_UPDATE_CHECK      = "true"
        AUTHENTIK_DISABLE_STARTUP_ANALYTICS = "true"
        # Note: Authentik does not yet support OTEL tracing (GitHub #12854)
        # Dynamic secrets from Vault
        AUTHENTIK_SECRET_KEY                = "${secret.authentik.secret_key}"
        AUTHENTIK_POSTGRESQL__HOST          = "${secret.authentik.postgres_host}"
        AUTHENTIK_POSTGRESQL__PORT          = "${secret.authentik.postgres_port}"
        AUTHENTIK_POSTGRESQL__NAME          = "${secret.authentik.postgres_db}"
        AUTHENTIK_POSTGRESQL__USER          = "${secret.authentik.postgres_user}"
        AUTHENTIK_POSTGRESQL__PASSWORD      = "${secret.authentik.postgres_password}"
        AUTHENTIK_REDIS__PASSWORD           = "${secret.redis_shared.password}"
      }

      # --- Resources ---
      resources {
        cpu    = 1000
        memory = 1024
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
