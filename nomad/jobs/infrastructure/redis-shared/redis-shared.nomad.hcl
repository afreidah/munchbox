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

    # -------------------------------------------------------------------------
    # Task: Redis
    # -------------------------------------------------------------------------

    task "redis" {
      driver = "docker"

      # --- Container Configuration ---
      config {
        image              = "redis:7-alpine"
        image_pull_timeout = "10m"
        ports              = ["redis"]
        args               = [
          "--save", "60", "1",
          "--loglevel", "warning",
          "--maxmemory", "512mb",
          "--maxmemory-policy", "allkeys-lru"
        ]
        volumes = [
          "/mnt/gdrive-secondary/redis-shared:/data",
        ]
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
          name     = "redis-health"
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # --- Resources ---
      resources {
        cpu    = 200
        memory = 512
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
