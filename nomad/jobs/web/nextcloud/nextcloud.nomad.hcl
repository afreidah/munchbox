# -------------------------------------------------------------------------------
# Nextcloud — Self-hosted Cloud Storage and Collaboration Platform
#
# Project: Munchbox / Author: Alex Freidah
#
# Nextcloud with Redis for caching/locking and cron for background jobs.
# Uses Postgres for database and stores user data on /mnt/gdrive.
# -------------------------------------------------------------------------------

job "nextcloud" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # -------------------------------------------------------------------------
  # Update Strategy
  # -------------------------------------------------------------------------

  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
    auto_promote      = true
  }

  # -------------------------------------------------------------------------
  # Task Group: nextcloud
  # -------------------------------------------------------------------------

  group "nextcloud" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    # -----------------------------------------------------------------------
    # Network Configuration
    # -----------------------------------------------------------------------
      
    network {
      mode = "bridge"
      port "http" {
        to     = 80
        static = 18081
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

    # -----------------------------------------------------------------------
    # Service Registration
    # -----------------------------------------------------------------------

    service {
      name     = "nextcloud"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.nextcloud.rule=Host(`nextcloud.munchbox.cc`)",
        "traefik.http.routers.nextcloud.entrypoints=websecure",
        "traefik.http.routers.nextcloud.tls=true",
        "traefik.http.routers.nextcloud.middlewares=dashboard-allowlan@file",
        "traefik.http.services.nextcloud.loadbalancer.server.port=80",
        "cloud",
        "files",
        "collaboration",
        "web"
      ]

      check {
        name     = "nextcloud-health"
        type     = "http"
        path     = "/status.php"
        port     = "http"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: nextcloud
    # -----------------------------------------------------------------------

    task "nextcloud" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "nextcloud:apache"
        image_pull_timeout = "10m"
        volumes            = [
          "/mnt/gdrive/nextcloud/data:/var/www/html/data",
          "/opt/nomad/data/nextcloud/config:/var/www/html/config",
          "/opt/nomad/data/nextcloud/apps:/var/www/html/custom_apps"
        ]
      }

      # --- Static Environment Variables ---
      env {
        POSTGRES_HOST        = "postgres-shared.service.consul"
        POSTGRES_DB          = "nextcloud"
        REDIS_HOST           = "127.0.0.1"
        REDIS_PORT           = "6379"
        NEXTCLOUD_ADMIN_USER = "admin"
        TRUSTED_PROXIES      = "172.26.64.0/18"
        OVERWRITEPROTOCOL    = "https"
        OVERWRITEHOST        = "nextcloud.munchbox.cc"
        OVERWRITECLIURL      = "https://nextcloud.munchbox.cc"
      }

      # --- Dynamic Secrets from Vault ---
      template {
        destination = "secrets/nextcloud.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{ with secret "secret/data/nextcloud" }}
POSTGRES_USER={{ .Data.data.db_username }}
POSTGRES_PASSWORD={{ .Data.data.db_password }}
NEXTCLOUD_ADMIN_PASSWORD={{ .Data.data.admin_password }}
{{ end }}
EOH
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 768
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }

    # -----------------------------------------------------------------------
    # Sidecar Task: redis
    # -----------------------------------------------------------------------

    task "redis" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "redis:7-alpine"
        args  = [
          "redis-server",
          "--maxmemory", "128mb",
          "--maxmemory-policy", "allkeys-lru"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # Sidecar Task: cron
    # -----------------------------------------------------------------------

    task "cron" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      config {
        image      = "nextcloud:apache"
        entrypoint = ["/cron.sh"]
        volumes    = [
          "/mnt/gdrive/nextcloud/data:/var/www/html/data",
          "/opt/nomad/data/nextcloud/config:/var/www/html/config",
          "/opt/nomad/data/nextcloud/apps:/var/www/html/custom_apps"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  meta = {
    managed_by = "nomad"
    project    = "munchbox"
  }
}
