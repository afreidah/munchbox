# -------------------------------------------------------------------------------
# Promtail — Nomad System Job for log collection (v3.3.1 FINAL)
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  meta {
    version     = "3.3.1"
    updated     = "2025-10-31"
    description = "Promtail log collection agent - file-based for containers"
  }

  group "promtail" {
    network {
      mode = "host"
      port "http" {
        static = 9080
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      stagger          = "30s"
    }

    task "promtail" {
      driver = "docker"

      config {
        image        = "grafana/promtail:3.3.1"
        network_mode = "host"
        ports        = ["http"]

        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]

        args = [
          "-config.file=/etc/promtail/config.yaml",
        ]

        volumes = [
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "local/config:/etc/promtail:ro",
          "/opt/nomad/alloc:/opt/nomad/alloc:ro",
          "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro",
        ]
      }

      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        left_delimiter  = "[["
        right_delimiter = "]]"

        data = <<-YAML
          server:
            http_listen_port: 9080
            log_level: info

          clients:
            - url: http://loki.service.consul:3100/loki/api/v1/push

          scrape_configs:
            # -----------------------------------------------------------------
            # Systemd journal
            # -----------------------------------------------------------------
            - job_name: systemd-journal
              journal:
                path: /var/log/journal
                max_age: 12h
                labels:
                  job: systemd-journal
                  node: [[ env "HOSTNAME" ]]

              relabel_configs:
                - source_labels: ['__journal__systemd_unit']
                  target_label: 'unit'
                - source_labels: ['__journal__hostname']
                  target_label: 'hostname'
                - source_labels: ['__journal__syslog_identifier']
                  regex: '(.+)'
                  target_label: 'service'
                - source_labels: ['__journal__priority']
                  target_label: 'priority'

              pipeline_stages:
                - template:
                    source: level
                    template: |
                      {{- $p := .Labels.priority -}}
                      {{- if eq $p "0" -}}emerg
                      {{- else if eq $p "1" -}}alert
                      {{- else if eq $p "2" -}}crit
                      {{- else if eq $p "3" -}}error
                      {{- else if eq $p "4" -}}warning
                      {{- else if eq $p "5" -}}notice
                      {{- else if eq $p "6" -}}info
                      {{- else if eq $p "7" -}}debug
                      {{- else -}}unknown{{- end -}}
                - labels:
                    level:
                - json:
                    expressions:
                      msg: message
                      level: level

            # -----------------------------------------------------------------
            # Systemd journal (volatile)
            # -----------------------------------------------------------------
            - job_name: systemd-journal-volatile
              journal:
                path: /run/log/journal
                max_age: 12h
                labels:
                  job: systemd-journal
                  node: [[ env "HOSTNAME" ]]

              relabel_configs:
                - source_labels: ['__journal__systemd_unit']
                  target_label: 'unit'
                - source_labels: ['__journal__hostname']
                  target_label: 'hostname'
                - source_labels: ['__journal__syslog_identifier']
                  regex: '(.+)'
                  target_label: 'service'
                - source_labels: ['__journal__priority']
                  target_label: 'priority'

              pipeline_stages:
                - template:
                    source: level
                    template: |
                      {{- $p := .Labels.priority -}}
                      {{- if eq $p "0" -}}emerg
                      {{- else if eq $p "1" -}}alert
                      {{- else if eq $p "2" -}}crit
                      {{- else if eq $p "3" -}}error
                      {{- else if eq $p "4" -}}warning
                      {{- else if eq $p "5" -}}notice
                      {{- else if eq $p "6" -}}info
                      {{- else if eq $p "7" -}}debug
                      {{- else -}}unknown{{- end -}}
                - labels:
                    level:
                - json:
                    expressions:
                      msg: message
                      level: level

            # -----------------------------------------------------------------
            # Nomad stdout logs - FIFO-safe pattern
            # -----------------------------------------------------------------
            - job_name: nomad-stdout
              static_configs:
                - targets: [localhost]
                  labels:
                    job: nomad-alloc
                    node: [[ env "HOSTNAME" ]]
                    stream: stdout
                    __path__: /opt/nomad/alloc/*/alloc/logs/*.stdout.[0-9]*

                - targets: [localhost]
                  labels:
                    job: nomad-alloc
                    node: [[ env "HOSTNAME" ]]
                    stream: stdout
                    __path__: /opt/nomad/data/alloc/*/alloc/logs/*.stdout.[0-9]*

              pipeline_stages:
                - regex:
                    source: filename
                    expression: '.*/alloc/(?P<alloc_id>[^/]+)/alloc/logs/(?P<task_name>[^.]+)\.stdout\.\d+'
                - labels:
                    alloc_id:
                    task_name:
                - json:
                    expressions:
                      level: level
                      msg: msg
                      message: message
                - match:
                    selector: '{job="nomad-alloc"}'
                    stages:
                      - drop:
                          expression: '^\s*$'

            # -----------------------------------------------------------------
            # Nomad stderr logs - FIFO-safe pattern
            # -----------------------------------------------------------------
            - job_name: nomad-stderr
              static_configs:
                - targets: [localhost]
                  labels:
                    job: nomad-alloc
                    node: [[ env "HOSTNAME" ]]
                    stream: stderr
                    __path__: /opt/nomad/alloc/*/alloc/logs/*.stderr.[0-9]*

                - targets: [localhost]
                  labels:
                    job: nomad-alloc
                    node: [[ env "HOSTNAME" ]]
                    stream: stderr
                    __path__: /opt/nomad/data/alloc/*/alloc/logs/*.stderr.[0-9]*

              pipeline_stages:
                - regex:
                    source: filename
                    expression: '.*/alloc/(?P<alloc_id>[^/]+)/alloc/logs/(?P<task_name>[^.]+)\.stderr\.\d+'
                - labels:
                    alloc_id:
                    task_name:
                - json:
                    expressions:
                      level: level
                      msg: msg
                      message: message
                - match:
                    selector: '{job="nomad-alloc"}'
                    stages:
                      - drop:
                          expression: '^\s*$'

          positions:
            filename: /alloc/data/positions.yaml

          limits_config:
            readline_rate_enabled: true
            readline_rate: 10000
            readline_burst: 20000
            readline_rate_drop: false
        YAML
      }

      env {
        TZ       = "America/Los_Angeles"
        HOSTNAME = "${node.unique.name}"
      }

      resources {
        cpu    = 150
        memory = 128
      }

      service {
        name     = "promtail"
        port     = "http"
        provider = "consul"
        tags     = ["logging", "promtail"]

        check {
          name     = "promtail-ready"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
