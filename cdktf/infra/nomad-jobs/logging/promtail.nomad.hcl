# -------------------------------------------------------------------------------
# Promtail — Nomad System Job for log collection
#
# - Runs on ALL nodes (system job)
# - Scrapes journald for all systemd/Nomad logs
# - Scrapes Nomad allocation stdout/stderr from host (alloc + task logs)
# - Ships logs to Loki server
# - Adds labels for node, job, task for easy filtering
# - Enhancements:
#     * Derive friendly 'level' label from journald 'priority'
#     * Parse JSON fields for Grafana drilldowns (trace_id, status, etc.)
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  # ---------------------------------------------------------------------------
  # Job metadata
  # ---------------------------------------------------------------------------
  meta {
    version     = "3.2.0"
    updated     = "2025-10-23"
    description = "Promtail log collection agent"
  }

  group "promtail" {
    # -------------------------------------------------------------------------
    # Network configuration
    # -------------------------------------------------------------------------
    network {
      mode = "host"

      port "http" {
        static = 9080 # Promtail metrics/status port
      }
    }

    # -------------------------------------------------------------------------
    # Restart policy
    # -------------------------------------------------------------------------
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    # -------------------------------------------------------------------------
    # Update strategy for system jobs
    # -------------------------------------------------------------------------
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
        # DNS configuration for Consul service discovery
        dns_servers        = ["192.168.68.62", "192.168.68.64"]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]

        args = [
          "-config.file=/etc/promtail/config.yaml",
          # "-log.level=debug",  # uncomment for troubleshooting
        ]

        # ---------------------------------------------------------------------
        # Host mounts
        # ---------------------------------------------------------------------
        volumes = [
          # Journald (persistent + runtime)
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",

          # Promtail config
          "local/config:/etc/promtail:ro",

          # NEW: Nomad allocation logs (alloc-level and task-level)
          # Your node stores allocs under /opt/nomad/alloc; mount read-only.
          "/opt/nomad/alloc:/opt/nomad/alloc:ro",

          # Optional: if some nodes use /opt/nomad/data/alloc, mount that too.
          "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro",
        ]

        # Container logging goes to journald to make agent logs easy to find
        logging {
          type = "journald"
          config { tag = "promtail" }
        }
      }

      # -----------------------------------------------------------------------
      # Promtail configuration (templated into the container)
      # -----------------------------------------------------------------------
      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"

        # Keep Nomad's delimiters different so Promtail's {{ }} survive
        left_delimiter  = "[["
        right_delimiter = "]]"

        data = <<-YAML
          # -------------------------------------------------------------------
          # Promtail Configuration
          # -------------------------------------------------------------------
          server:
            http_listen_port: 9080
            log_level: info

          # Where to send logs (uses Consul DNS for service discovery)
          clients:
            - url: http://loki.service.consul:3100/loki/api/v1/push

          # -------------------------------------------------------------------
          # What to scrape
          # -------------------------------------------------------------------
          scrape_configs:
            # -----------------------------------------------------------------
            # Systemd journal (persistent)
            # -----------------------------------------------------------------
            - job_name: journal
              journal:
                path: /var/log/journal
                max_age: 12h
                labels:
                  job: systemd-journal
                  host: [[ env "HOSTNAME" ]]

              # Extract labels from journald fields
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

              # Pipeline: derive level, parse JSON if present, promote Nomad-ish ids from syslog_identifier
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

            # -----------------------------------------------------------------
            # Systemd journal (volatile)
            # -----------------------------------------------------------------
            - job_name: journal-volatile
              journal:
                path: /run/log/journal
                max_age: 12h
                labels:
                  job: systemd-journal
                  host: [[ env "HOSTNAME" ]]

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

            # -----------------------------------------------------------------
            # NEW: Nomad allocation and task logs (stdout/stderr)
            # -----------------------------------------------------------------
            - job_name: nomad-allocs
              static_configs:
                # Primary path structure: /opt/nomad/alloc
                - targets: [localhost]
                  labels:
                    job: nomad
                    host: [[ env "HOSTNAME" ]]
                    __path__: /opt/nomad/alloc/*/alloc/logs/*.{stdout,stderr}.*
                
                # Alternative path structure: /opt/nomad/data/alloc  
                - targets: [localhost]
                  labels:
                    job: nomad
                    host: [[ env "HOSTNAME" ]]
                    __path__: /opt/nomad/data/alloc/*/alloc/logs/*.{stdout,stderr}.*

              # Enhanced pipeline to extract task names from filenames
              pipeline_stages:
                # Extract labels from the file path
                - regex:
                    source: filename
                    # Matches: /path/to/alloc/{alloc-id}/alloc/logs/{task}.{stdout|stderr}.{n}
                    expression: '.*/alloc/(?P<alloc_id>[^/]+)/alloc/logs/(?P<task_name>[^.]+)\.(?P<stream>stdout|stderr)\.\d+'
                
                - labels:
                    alloc_id:
                    task_name:
                    stream:
                
                # Optional: Parse JSON logs if your services emit structured logs
                - json:
                    expressions:
                      level: level
                      msg: msg
                      trace_id: trace_id
                    source: log
                
                # Drop empty lines to reduce noise
                - match:
                    selector: '{job="nomad"}'
                    stages:
                      - drop:
                          expression: '^\s*$'

          # -------------------------------------------------------------------
          # Positions file to track what's been read
          # -------------------------------------------------------------------
          positions:
            filename: /tmp/positions.yaml

          # -------------------------------------------------------------------
          # Limits
          # -------------------------------------------------------------------
          limits_config:
            readline_rate_enabled: false
            #readline_rate: 100
            #readline_burst: 1000
        YAML
      }

      # -----------------------------------------------------------------------
      # Environment variables (HOSTNAME used inside Promtail config)
      # -----------------------------------------------------------------------
      env {
        TZ       = "America/Los_Angeles"
        HOSTNAME = "${node.unique.name}"
      }

      # -----------------------------------------------------------------------
      # Resource allocation - very lightweight
      # -----------------------------------------------------------------------
      resources {
        cpu    = 100 # MHz
        memory = 128 # MB
      }

      # -----------------------------------------------------------------------
      # Lifecycle management
      # -----------------------------------------------------------------------
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
