# -------------------------------------------------------------------------------
#  Alertmanager — Alert Routing and Notification Service with Telegram
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Receives alerts from Prometheus, groups and routes them according to rules,
#  manages silences and inhibition, and sends formatted notifications via Telegram
#  bot integration. Provides web UI with LAN-only access via Traefik routing.
# -------------------------------------------------------------------------------

job "alertmanager" {
  region      = "global"
  namespace   = "default"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Alertmanager Group
  # ---------------------------------------------------------------------------

  group "am" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
      port "web" {
        static = 9093
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 5
      interval = "10m"
      delay    = "15s"
      mode     = "delay"
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
    #  Alertmanager Task
    # -----------------------------------------------------------------------

    task "alertmanager" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image        = "quay.io/prometheus/alertmanager:v0.28.1"
        network_mode = "host"
        ports        = ["web"]
        args = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--web.listen-address=0.0.0.0:9093",
          "--web.external-url=https://alertmanager.munchbox/",
          "--cluster.listen-address="
        ]
        volumes = [
          "local/config:/etc/alertmanager:ro"
        ]
      }

      # --- Service registration ---
      service {
        name         = "alertmanager"
        provider     = "consul"
        port         = "web"
        address_mode = "host"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.alertmanager.rule=Host(`alertmanager.munchbox`)",
          "traefik.http.routers.alertmanager.entrypoints=websecure",
          "traefik.http.routers.alertmanager.tls=true",
          "traefik.http.routers.alertmanager.middlewares=dashboard-allowlan@file",
          "traefik.http.services.alertmanager.loadbalancer.server.port=9093",
          "traefik.http.services.alertmanager.loadbalancer.server.scheme=http",
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.path=/-/ready",
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.alertmanager.loadbalancer.healthcheck.timeout=5s",
          "monitoring",
          "alertmanager",
          "notifications",
          "telegram"
        ]

        # --- Primary health check ---
        check {
          name     = "am-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "3s"
        }

        # --- Secondary health check ---
        check {
          name     = "am-healthy"
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "5s"
        }
      }

      # --- Alertmanager configuration template ---
      # Delimiter configuration: uses [[ ]] to avoid conflicts with Alertmanager's {{ }} templates
      # Renders alertmanager.yml from injected configuration file with Telegram integration
      # Signal mode allows Alertmanager to reload config on file changes via SIGHUP
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

      # --- Runtime environment ---
      env {
        TZ                                  = "America/Los_Angeles"
        ALERTMANAGER_WEB_EXTERNAL_URL       = "https://alertmanager.munchbox/"
        ALERTMANAGER_CLUSTER_LISTEN_ADDRESS = ""
      }

      # --- Resource allocation ---
      # Lightweight allocation suitable for alerting service
      resources {
        cpu    = 150
        memory = 128
      }

      # --- Termination configuration ---
      # Allow pending notifications to be sent before shutdown
      kill_timeout   = "30s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "15s"
    }
  }
}
