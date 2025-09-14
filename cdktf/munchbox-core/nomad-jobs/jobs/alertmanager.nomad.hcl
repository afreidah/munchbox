# -----------------------------------------------------------------------------
# Alertmanager — Nomad Job (stateless, Telegram via Nomad Variables)
#
# Put your secrets here (job-scoped path; auto-readable by this task):
#   nomad var put -namespace=default nomad/jobs/alertmanager \
#     telegram_bot_token="$TOKEN" \
#     telegram_chat_id="8061235073"
#
# Notes:
# - No persistent volume (silences/history reset on restart).
# - Uses [[...]] so Nomad won’t evaluate Alertmanager’s {{...}} templates.
# -----------------------------------------------------------------------------
job "alertmanager" {
  region      = "global"
  namespace   = "default"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  group "am" {
    count = 1

    # (optional) pin to a node
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "stabler"
    }

    network {
      mode = "host"

      port "web" {
        static = 9093
      }
    }

    task "alertmanager" {
      driver = "docker"

      config {
        image        = "quay.io/prometheus/alertmanager:v0.27.0"
        network_mode = "host"
        ports        = ["web"]

        args = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--web.listen-address=0.0.0.0:9093"
        ]

        volumes = [
          "local/config:/etc/alertmanager"
        ]
      }

      service {
        name         = "alertmanager"
        provider     = "consul"
        port         = "web"
        address_mode = "host"

        check {
          name     = "am-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # Leave Alertmanager's {{...}} alone; only render Nomad Vars with [[...]].
      template {
        destination     = "local/config/alertmanager.yml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "[["
        right_delimiter = "]]"

        data = <<-YAML
          global:
            resolve_timeout: 5m

          route:
            receiver: "telegram"
            group_by: ['alertname','instance']
            group_wait: 30s
            group_interval: 5m
            repeat_interval: 2h

          receivers:
            - name: "telegram"
              telegram_configs:
                - bot_token: '[[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_bot_token ]][[ end ]]'
                  # chat_id must be numeric; render without quotes:
                  chat_id: [[ with nomadVar "nomad/jobs/alertmanager" ]][[ .telegram_chat_id ]][[ end ]]
                  parse_mode: "HTML"
                  message: |
                    <b>{{ .CommonLabels.alertname }}</b> {{ if eq .Status "firing" }}🔥{{ else }}✅{{ end }}<br/>
                    <b>Status:</b> {{ .Status }}<br/>
                    <b>Instance:</b> {{ .CommonLabels.instance }}<br/>
                    {{- with (index .Alerts 0).Annotations.summary }}
                    <b>Summary:</b> {{ . }}<br/>
                    {{- end }}
                    {{- with (index .Alerts 0).Annotations.description }}
                    <b>Description:</b> {{ . }}<br/>
                    {{- end }}
                    {{- if .ExternalURL }}
                    <a href="{{ .ExternalURL }}">Open Alertmanager</a>
                    {{- end }}
                  send_resolved: true

          inhibit_rules:
            - source_matchers: [ 'severity="critical"' ]
              target_matchers: [ 'severity=~"warning|info"' ]
              equal: ['alertname','instance']
        YAML
      }

      env {
        TZ = "America/Los_Angeles"
      }

      resources {
        cpu    = 150
        memory = 128
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "5s"
        mode     = "delay"
      }
    }
  }
}
