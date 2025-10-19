# -------------------------------------------------------------------------------
# Promtail — Nomad System Job for log collection
#
# - Runs on ALL nodes (system job)
# - Scrapes journald for all systemd/Nomad logs
# - Ships logs to Loki server
# - Adds labels for node, job, task for easy filtering
# - Enhancements:
#     * Derive friendly 'level' label from journald 'priority'
#     * Parse JSON/logfmt fields for Grafana drilldowns (trace_id, status, etc.)
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  # Job metadata
  meta {
    version     = "3.2.0"
    updated     = "2025-10-12"
    description = "Promtail log collection agent"
  }

  group "promtail" {
    # Network configuration
    network {
      mode = "host"

      port "http" {
        static = 9080 # Promtail metrics/status port
      }
    }

    # Restart policy
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # Update strategy for system jobs
    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      stagger          = "30s" # Wait between node updates
    }

    task "promtail" {
      driver = "docker"

      config {
        image        = "grafana/promtail:3.2.0"
        network_mode = "host"
        ports        = ["http"]

        args = [
          "-config.file=/etc/promtail/config.yaml",
          # "-log.level=debug", # uncomment for troubleshooting
        ]

        # Mount journald and Promtail config
        volumes = [
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "local/config:/etc/promtail:ro",
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "promtail"
          }
        }
      }

      # Promtail configuration
      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"

        # IMPORTANT: keep Nomad's delimiters different so Promtail's {{ }} survive
        left_delimiter  = "[["
        right_delimiter = "]]"

        data = <<-YAML
# Promtail Configuration
server:
  http_listen_port: 9080
  log_level: info

# Where to send logs (uses Consul DNS for service discovery)
clients:
  - url: http://loki.service.consul:3100/loki/api/v1/push

# What to scrape
scrape_configs:
  # Scrape all journald logs (persistent)
  - job_name: journal
    journal:
      path: /var/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
        host: ${node.unique.name}

    # Extract labels from journald fields
    relabel_configs:
      # Add node name
      - source_labels: ['__journal__hostname']
        target_label: 'node'

      # Add systemd unit name
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'

      # Extract syslog identifier safely (correct field name with double underscores)
      - source_labels: ['__journal__syslog_identifier']
        regex: '(.+)'
        target_label: 'syslog_identifier'

      # Add priority level (0..7) (correct field name with double underscores)
      - source_labels: ['__journal__priority']
        target_label: 'priority'

    # Pipeline stages to parse Nomad logs & enrich labels
    pipeline_stages:
      # Extract Nomad allocation info from journald identifier
      - regex:
          expression: '(?P<nomad_job>[a-zA-Z0-9_-]+)\.(?P<nomad_group>[a-zA-Z0-9_-]+)\.(?P<nomad_task>[a-zA-Z0-9_-]+)'
          source: syslog_identifier

      # Promote extracted Nomad labels (low cardinality)
      - labels:
          nomad_job:
          nomad_group:
          nomad_task:

      # Derive human-readable 'level' from journald numeric 'priority'
      - template:
          source: level
          template: |
            {{- $p := .Labels.priority -}}
            {{- if eq $p "0" -}}emerg
            {{- else if eq $p "1" -}}alert
            {{- else if eq $p "2" -}}crit
            {{- else if eq $p "3" -}}err
            {{- else if eq $p "4" -}}warning
            {{- else if eq $p "5" -}}notice
            {{- else if eq $p "6" -}}info
            {{- else -}}debug{{- end -}}

      - labels:
          level:

      # Parse structured payloads for Grafana drilldowns (no-op if not JSON/logfmt)
      - json:
          expressions:
            level: level
            msg: message
            trace_id: trace_id
            span_id: span_id
            status: status

      - logfmt:
          mapping:
            level: level
            msg: msg
            trace_id: trace_id
            span_id: span_id
            status: status

  # Scrape journald from /run/log/journal (volatile; e.g., Raspbian nodes)
  - job_name: journal-volatile
    journal:
      path: /run/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
        host: ${node.unique.name}

    relabel_configs:
      - source_labels: ['__journal__hostname']
        target_label: 'node'
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__syslog_identifier']
        regex: '(.+)'
        target_label: 'syslog_identifier'
      - source_labels: ['__journal__priority']
        target_label: 'priority'

    pipeline_stages:
      - regex:
          expression: '(?P<nomad_job>[a-zA-Z0-9_-]+)\.(?P<nomad_group>[a-zA-Z0-9_-]+)\.(?P<nomad_task>[a-zA-Z0-9_-]+)'
          source: syslog_identifier
      - labels:
          nomad_job:
          nomad_group:
          nomad_task:

      - template:
          source: level
          template: |
            {{- $p := .Labels.priority -}}
            {{- if eq $p "0" -}}emerg
            {{- else if eq $p "1" -}}alert
            {{- else if eq $p "2" -}}crit
            {{- else if eq $p "3" -}}err
            {{- else if eq $p "4" -}}warning
            {{- else if eq $p "5" -}}notice
            {{- else if eq $p "6" -}}info
            {{- else -}}debug{{- end -}}
      - labels:
          level:

      - json:
          expressions:
            level: level
            msg: message
            trace_id: trace_id
            span_id: span_id
            status: status
      - logfmt:
          mapping:
            level: level
            msg: msg
            trace_id: trace_id
            span_id: span_id
            status: status

# Positions file to track what's been read
positions:
  filename: /tmp/positions.yaml

# Limits
limits_config:
  readline_rate_enabled: true
  readline_rate: 100
  readline_burst: 1000
YAML
      }

      # Environment variables
      env {
        TZ       = "America/Los_Angeles"
        HOSTNAME = "${node.unique.name}"
      }

      # Resource allocation - very lightweight
      resources {
        cpu    = 100 # MHz
        memory = 128 # MB
      }

      # Lifecycle management
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
