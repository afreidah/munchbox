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

    # Pin to same node as Prometheus for reliable communication
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    # Network configuration
    network {
      mode = "host"

      port "web" {
        static = 9093  # Standard Alertmanager port
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
          "--cluster.listen-address="  # Disable clustering for single instance
        ]

        # Volume mounts
        volumes = [
          "local/config:/etc/alertmanager:ro"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "alertmanager"
          }
        }
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
        data = <<-YAML
# Alertmanager Configuration v0.28.1
# Handles alert routing, grouping, and notification delivery

global:
  # Default timeout for resolving alerts
  resolve_timeout: 5m

# Alert routing configuration
route:
  # Default receiver for all alerts
  receiver: 'telegram'

  # Group alerts by these labels to reduce noise
  group_by: ['alertname', 'instance', 'severity']

  # Wait time before sending grouped alerts
  group_wait: 30s

  # Interval between sending grouped alerts
  group_interval: 5m

  # Minimum interval before resending an alert
  repeat_interval: 2h

  # Child routes for specific alert handling
  routes:
    # Critical alerts - send immediately with shorter repeat
    - matchers:
        - severity="critical"
      receiver: 'telegram-critical'
      group_wait: 10s
      repeat_interval: 30m

    # Warning alerts - group longer to reduce noise
    - matchers:
        - severity="warning"
      receiver: 'telegram-warnings'
      group_wait: 2m
      group_interval: 10m
      repeat_interval: 4h

# Notification receivers
receivers:
  # Default Telegram receiver
  - name: 'telegram'
    telegram_configs:
      - bot_token: '[[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_bot_token ]][[ end ]]'
        chat_id: [[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_chat_id ]][[ end ]]
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          <b>🚨 {{ .GroupLabels.alertname }}</b> {{ if eq .Status "firing" }}🔥{{ else }}✅{{ end }}

          <b>Status:</b> {{ .Status | toUpper }}
          <b>Severity:</b> {{ .CommonLabels.severity | toUpper }}
          <b>Instance:</b> {{ .CommonLabels.instance }}
          {{- if .CommonLabels.job }}
          <b>Job:</b> {{ .CommonLabels.job }}
          {{- end }}

          {{- range .Alerts }}
          {{- if .Annotations.summary }}
          <b>Summary:</b> {{ .Annotations.summary }}
          {{- end }}
          {{- if .Annotations.description }}
          <b>Description:</b> {{ .Annotations.description }}
          {{- end }}
          {{- end }}

          {{- if .ExternalURL }}
          <a href="{{ .ExternalURL }}">🔗 View in Alertmanager</a>
          {{- end }}

  # Critical alerts receiver - more urgent formatting
  - name: 'telegram-critical'
    telegram_configs:
      - bot_token: '[[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_bot_token ]][[ end ]]'
        chat_id: [[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_chat_id ]][[ end ]]
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          🚨🚨 <b>CRITICAL ALERT</b> 🚨🚨

          <b>{{ .GroupLabels.alertname }}</b>
          <b>Status:</b> {{ .Status | toUpper }}
          <b>Instance:</b> {{ .CommonLabels.instance }}

          {{- range .Alerts }}
          <b>⚠️ {{ .Annotations.summary }}</b>
          {{ .Annotations.description }}
          {{- end }}

          <a href="{{ .ExternalURL }}">🔗 RESOLVE NOW</a>

  # Warning alerts receiver - less urgent formatting
  - name: 'telegram-warnings'
    telegram_configs:
      - bot_token: '[[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_bot_token ]][[ end ]]'
        chat_id: [[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_chat_id ]][[ end ]]
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          ⚠️ <b>{{ .GroupLabels.alertname }}</b>

          <b>Status:</b> {{ .Status }}
          <b>Instance:</b> {{ .CommonLabels.instance }}

          {{- range .Alerts }}
          {{ .Annotations.summary }}
          {{- end }}

# Inhibition rules - suppress lower severity alerts when higher ones are active
inhibit_rules:
  # Suppress warnings when critical alerts are firing for same instance
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity=~"warning|info"
    equal: ['alertname', 'instance']

  # Suppress node alerts when the entire node is down
  - source_matchers:
      - alertname="ServiceDown"
    target_matchers:
      - alertname=~"HighCPUUsage|HighMemoryUsage|DiskSpaceLow"
    equal: ['instance']

# Silencing templates for common maintenance scenarios
templates:
  - '/etc/alertmanager/templates/*.tmpl'
YAML
      }

      # Environment variables
      env {
        TZ = "America/Los_Angeles"

        # Alertmanager specific settings
        ALERTMANAGER_WEB_EXTERNAL_URL = "https://alertmanager.munchbox/"
        ALERTMANAGER_CLUSTER_LISTEN_ADDRESS = ""  # Disable clustering
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
