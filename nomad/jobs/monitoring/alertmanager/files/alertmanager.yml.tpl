# Alertmanager Configuration v0.27.0
# Handles alert routing, grouping, and notification delivery

global:
  resolve_timeout: 5m

route:
  receiver: 'telegram'
  group_by: ['alertname', 'instance', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 2h

  routes:
    - matchers:
        - severity="critical"
      receiver: 'telegram-critical'
      group_wait: 10s
      repeat_interval: 30m

    - matchers:
        - severity="warning"
      receiver: 'telegram-warnings'
      group_wait: 2m
      group_interval: 10m
      repeat_interval: 4h

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '{{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_bot_token }}{{ end }}'
        chat_id: {{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_chat_id }}{{ end }}
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          <b>ALERT {{ "{{" }} .GroupLabels.alertname {{ "}}" }}</b> {{ "{{" }} if eq .Status "firing" {{ "}}" }}FIRING{{ "{{" }} else {{ "}}" }}RESOLVED{{ "{{" }} end {{ "}}" }}

          <b>Status:</b> {{ "{{" }} .Status {{ "}}" }}
          <b>Severity:</b> {{ "{{" }} .CommonLabels.severity {{ "}}" }}
          <b>Instance:</b> {{ "{{" }} .CommonLabels.instance {{ "}}" }}
          {{ "{{-" }} if .CommonLabels.job {{ "}}" }}
          <b>Job:</b> {{ "{{" }} .CommonLabels.job {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
          {{ "{{-" }} range .Alerts {{ "}}" }}
          {{ "{{-" }} if .Annotations.summary {{ "}}" }}
          <b>Summary:</b> {{ "{{" }} .Annotations.summary {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
          {{ "{{-" }} if .Annotations.description {{ "}}" }}
          <b>Description:</b> {{ "{{" }} .Annotations.description {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
          {{ "{{-" }} if .ExternalURL {{ "}}" }}
          <a href="{{ "{{" }} .ExternalURL {{ "}}" }}">View in Alertmanager</a>
          {{ "{{-" }} end {{ "}}" }}

  - name: 'telegram-critical'
    telegram_configs:
      - bot_token: '{{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_bot_token }}{{ end }}'
        chat_id: {{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_chat_id }}{{ end }}
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          <b>CRITICAL ALERT</b>

          <b>{{ "{{" }} .GroupLabels.alertname {{ "}}" }}</b>
          <b>Status:</b> {{ "{{" }} .Status {{ "}}" }}
          <b>Instance:</b> {{ "{{" }} .CommonLabels.instance {{ "}}" }}
          {{ "{{-" }} range .Alerts {{ "}}" }}
          <b>{{ "{{" }} .Annotations.summary {{ "}}" }}</b>
          {{ "{{" }} .Annotations.description {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
          <a href="{{ "{{" }} .ExternalURL {{ "}}" }}">RESOLVE NOW</a>

  - name: 'telegram-warnings'
    telegram_configs:
      - bot_token: '{{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_bot_token }}{{ end }}'
        chat_id: {{ with secret "secret/data/alertmanager" }}{{ .Data.data.telegram_chat_id }}{{ end }}
        parse_mode: 'HTML'
        send_resolved: true
        message: |
          <b>WARNING {{ "{{" }} .GroupLabels.alertname {{ "}}" }}</b>

          <b>Status:</b> {{ "{{" }} .Status {{ "}}" }}
          <b>Instance:</b> {{ "{{" }} .CommonLabels.instance {{ "}}" }}
          {{ "{{-" }} range .Alerts {{ "}}" }}
          {{ "{{" }} .Annotations.summary {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}

inhibit_rules:
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity=~"warning|info"
    equal: ['alertname', 'instance']

  - source_matchers:
      - alertname="ServiceDown"
    target_matchers:
      - alertname=~"HighCPUUsage|HighMemoryUsage|DiskSpaceLow"
    equal: ['instance']
