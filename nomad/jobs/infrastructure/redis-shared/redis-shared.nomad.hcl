# -------------------------------------------------------------------------------
# Redis Shared — Centralized Redis Cache and Message Broker
#
# Project: Munchbox / Author: Alex Freidah
#
# Shared Redis instance for multiple services requiring caching or pub/sub.
# Uses numbered databases for tenant isolation (db0=nextcloud, db1=authentik).
# -------------------------------------------------------------------------------

job "redis-shared" {
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
  # Task Group: Redis
  # ---------------------------------------------------------------------------

  group "redis" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "bridge"
      port "redis" {
        static = 6379
        to     = 6379
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
      name     = "redis-shared"
      port     = "redis"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "redis",
        "shared",
      ]

      check {
        name     = "redis-tcp"
        type     = "tcp"
        port     = "redis"
        interval = "10s"
        timeout  = "2s"
        on_update = "require_healthy"
      }

      deregister_critical_service_after = "1m"
    }

    # -------------------------------------------------------------------------
    # Task: Redis
    # -------------------------------------------------------------------------

    task "redis" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Container Configuration ---
      config {
        image              = "redis:8-alpine"
        image_pull_timeout = "10m"
        ports              = ["redis"]
        args               = [
          "/usr/local/etc/redis/redis.conf"
        ]
        volumes = [
          "/mnt/gdrive-secondary/redis-shared:/data",
          "local/redis.conf:/usr/local/etc/redis/redis.conf:ro"
        ]
      }

      # --- Redis Configuration Template ---
      template {
        destination = "local/redis.conf"
        change_mode = "restart"
        data        = <<EOH
# Redis configuration
save 60 1
loglevel warning
maxmemory 512mb
maxmemory-policy allkeys-lru
dir /data
{{ with secret "secret/data/redis-shared" }}
requirepass {{ .Data.data.password }}
{{ end }}
EOH
      }

      # --- Resources ---
      resources {
        cpu    = 200    # Keep CPU - usage reasonable at 0.6%
        memory = 128    # Reduced from 512 - actual usage ~30MB
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
