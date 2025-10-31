# -----------------------------------------------------------------------------
# Alertmanager — Nomad Job with Telegram Integration (v0.28.1)
#
# Purpose:
#   - Receives alerts from Prometheus and handles notification routing
#   - Groups, silences, and inhibits alerts to reduce noise
#   - Sends notifications via Telegram bot integration
#   - Provides web UI for managing alerts and silences
#
# Architecture:
#   - Stateless service (silences/history reset on restart)
#   - Secrets stored in Nomad variables (secure, encrypted)
#   - Telegram notifications with HTML formatting
#   - Traefik routing with LAN-only access for web UI
#
# Setup Required:
#   nomad var put -namespace=default nomad/jobs/alertmanager \
#     telegram_bot_token="YOUR_BOT_TOKEN" \
#     telegram_chat_id="YOUR_CHAT_ID"
#
# Alert Flow:
#   1. Prometheus evaluates rules and fires alerts
#   2. Alertmanager receives alerts from Prometheus
#   3. Groups and routes alerts according to configuration
#   4. Sends formatted Telegram messages
#   5. Manages silences and inhibition rules
# -----------------------------------------------------------------------------

job "alertmanager" {
  region      = "global"
  namespace   = "default"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # Job metadata
  meta {
    version     = "0.28.1"
    updated     = "2025-10-03"
    description = "Alertmanager with Telegram notifications"
  }

  group "am" {
    count = 1

    # Network configuration
    network {
      mode = "host"

      port "web" {
        static = 9093 # Standard Alertmanager port
      }
    }

    # Restart policy - resilient for critical alerting
    restart {
      attempts = 5
      interval = "10m"
      delay    = "15s"
      mode     = "delay"
    }

    # Update strategy
    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      healthy_deadline  = "3m"
      progress_deadline = "10m"
      auto_revert       = true
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image        = "quay.io/prometheus/alertmanager:v0.28.1"
        network_mode = "host"
        ports        = ["web"]

        # Command line arguments
        args = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--web.listen-address=0.0.0.0:9093",
          "--web.external-url=https://alertmanager.munchbox/",
          "--cluster.listen-address=" # Disable clustering for single instance
        ]

        # Volume mounts
        volumes = [
          "local/config:/etc/alertmanager:ro"
        ]
      }

      # Consul service registration with Traefik v3 tags
      service {
        name         = "alertmanager"
        provider     = "consul"
        port         = "web"
        address_mode = "host"

        tags = [
          "traefik.enable=true",

          # Router configuration
          "traefik.http.routers.alertmanager.rule=Host(`alertmanager.munchbox`)",
          "traefik.http.routers.alertmanager.entrypoints=websecure",
          "traefik.http.routers.alertmanager.tls=true",

          # Security middleware - LAN only (defined in file provider)
          "traefik.http.routers.alertmanager.middlewares=dashboard-allowlan@file",

          # Service configuration
          "traefik.http.services.alertmanager.loadbalancer.server.port=9093",
          "traefik.http.services.alertmanager.loadbalancer.server.scheme=http",

          # Health check configuration
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.path=/-/ready",
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.timeout=5s",

          # Metadata tags
          "monitoring",
          "alertmanager",
          "notifications",
          "telegram"
        ]

        # Health checks
        check {
          name     = "am-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "3s"
        }

        check {
          name     = "am-healthy"
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "5s"
        }
      }

      # Alertmanager configuration with Telegram integration
      # Uses [[...]] delimiters to avoid conflicts with Alertmanager's {{...}} templates
      template {
        destination     = "local/config/alertmanager.yml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<-YAML
<<INJECT:files/alertmanager.yml>>
YAML
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles"

        # Alertmanager specific settings
        ALERTMANAGER_WEB_EXTERNAL_URL       = "https://alertmanager.munchbox/"
        ALERTMANAGER_CLUSTER_LISTEN_ADDRESS = "" # Disable clustering
      }

      # Resource allocation - lightweight for alerting service
      resources {
        cpu    = 150
        memory = 128
      }

      # Lifecycle management
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"

      # Allow time for pending notifications to be sent
      shutdown_delay = "15s"
    }
  }
}
