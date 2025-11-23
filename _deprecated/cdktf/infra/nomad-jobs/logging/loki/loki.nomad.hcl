# -------------------------------------------------------------------------------
#  Loki — Centralized Log Aggregation for Promtail Collectors
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Receives logs from Promtail agents on all nodes via push API. Maintains
#  5-day log retention with TSDB filesystem backend for persistence. Exposes
#  HTTP API for Grafana log queries and runs on cabot node with host volume.
# -------------------------------------------------------------------------------

job "loki" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  # --- Job metadata ---
  meta {
    version     = "3.3.1"
    updated     = "2025-10-31"
    description = "Loki log aggregation server"
    owner       = "alex.freidah"
    category    = "logging"
    tier        = "tier-1"
    environment = "production"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Loki Group
  # ---------------------------------------------------------------------------

  group "loki" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # --- Persistent TSDB storage volume ---
    volume "loki-data" {
      type      = "host"
      source    = "loki-data"
      read_only = false
    }

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 3100
        to     = 3100
      }
      port "grpc" {
        static = 9096
        to     = 9096
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Storage Preparation Prestart Task
    # -----------------------------------------------------------------------

    task "prepare-storage" {
      driver = "docker"
      user   = "root"

      lifecycle {
        hook = "prestart"
      }

      # --- Docker image configuration ---
      config {
        image   = "alpine:3.20"
        command = "sh"
        args = [
          "-c",
          <<-EOS
            set -euo pipefail
            mkdir -p /loki/chunks /loki/rules /loki/tsdb-index /loki/tsdb-cache /loki/compactor
            chown -R 10001:10001 /loki
            chmod -R 775 /loki
            ls -la /loki
          EOS
        ]
      }

      # --- Volume mount ---
      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      # --- Resource allocation ---
      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -----------------------------------------------------------------------
    #  Loki Task
    # -----------------------------------------------------------------------

    task "loki" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image        = "grafana/loki:3.3.1"
        network_mode = "host"
        ports        = ["http", "grpc"]
        args = [
          "-config.file=/etc/loki/config.yaml",
        ]
        volumes = [
          "local/config:/etc/loki:ro",
        ]
        logging {
          type = "journald"
          config { tag = "loki" }
        }
      }

      # --- Persistent storage volume mount ---
      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      # --- Loki configuration template ---
      # TSDB filesystem backend with 5-day retention
      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-YAML
<<INJECT:files/config.yaml>>
YAML
      }

      # --- Service registration ---
      service {
        name         = "loki"
        port         = "http"
        provider     = "consul"
        address_mode = "host"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.loki.rule=Host(`loki.munchbox`)",
          "traefik.http.routers.loki.entrypoints=websecure",
          "traefik.http.routers.loki.tls=true",
          "traefik.http.routers.loki.middlewares=dashboard-allowlan@file",
          "traefik.http.services.loki.loadbalancer.server.port=3100",
          "logging",
          "loki",
          "observability"
        ]

        # --- Loki health check ---
        check {
          name     = "loki-ready"
          type     = "http"
          path     = "/ready"
          port     = "http"
          interval = "10s"
          timeout  = "3s"
        }
      }

      # --- Runtime environment ---
      env {
        TZ = "America/Los_Angeles"
      }

      # --- Resource allocation ---
      resources {
        cpu    = 500
        memory = 512
      }

      # --- Termination configuration ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
