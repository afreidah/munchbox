# -------------------------------------------------------------------------------
# Loki — Nomad Job for centralized log aggregation (v3.3.1 FINAL)
#
# - Receives logs from Promtail agents on all nodes
# - 5-day log retention (TSDB, filesystem backend)
# - Persistent storage on cabot (host volume `loki-data`)
# - Exposes HTTP API for Grafana queries
# - Registers in Consul (address_mode=host) so loki.service.consul works
# -------------------------------------------------------------------------------

job "loki" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "edge"

  meta {
    version     = "3.3.1"
    updated     = "2025-10-31"
    description = "Loki log aggregation server"
    owner       = "alex.freidah"
    category    = "logging"
    tier        = "tier-1"
    environment = "production"
  }

  group "loki" {
    count = 1

    # Pin to cabot for persistent storage locality
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "cabot"
    }

    # Host volume for persistent TSDB data (define 'loki-data' in client.hcl)
    volume "loki-data" {
      type      = "host"
      source    = "loki-data"
      read_only = false
    }

    # Networking: host mode + static ports (open 3100/tcp & 9096/tcp on host)
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

    # Restart/update policies
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
    }

    # -------------------------------------------------------------------------
    # Prestart: ensure storage dirs exist & owned by Loki UID 10001
    # -------------------------------------------------------------------------
    task "prepare-storage" {
      driver = "docker"
      user   = "root"

      lifecycle { hook = "prestart" }

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

      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Main Loki task
    # -------------------------------------------------------------------------
    task "loki" {
      driver = "docker"

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

      # Mount persistent storage
      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
        read_only   = false
      }

      # ---- Loki config (filesystem TSDB, 5-day retention) -------------------
      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-YAML
<<INJECT:files/config.yaml>>
YAML
      }

      # Consul service registration (address_mode=host ensures host IP is used)
      service {
        name         = "loki"
        port         = "http"
        provider     = "consul"
        address_mode = "host"

        tags = [
          # Traefik routing (optional but kept from your setup)
          "traefik.enable=true",
          "traefik.http.routers.loki.rule=Host(`loki.munchbox`)",
          "traefik.http.routers.loki.entrypoints=websecure",
          "traefik.http.routers.loki.tls=true",
          "traefik.http.routers.loki.middlewares=dashboard-allowlan@file",
          "traefik.http.services.loki.loadbalancer.server.port=3100",

          # Metadata
          "logging",
          "loki",
          "observability",
        ]

        # Health check: only PASSING instances appear in loki.service.consul DNS
        check {
          name     = "loki-ready"
          type     = "http"
          path     = "/ready"
          port     = "http"
          interval = "10s"
          timeout  = "3s"
        }
      }

      env {
        TZ = "America/Los_Angeles"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
