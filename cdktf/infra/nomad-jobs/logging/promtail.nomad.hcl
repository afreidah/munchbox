# -------------------------------------------------------------------------------
# Promtail — Nomad System Job for log collection
#
# - Runs on ALL nodes (system job)
# - Scrapes journald for all systemd/Nomad logs
# - Ships logs to Loki server
# - Adds labels for node, job, task for easy filtering
# -------------------------------------------------------------------------------

job "promtail" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "system"
  node_pool   = "all"

  # Job metadata
  meta {
    version     = "3.2.0"
    updated     = "2025-10-07"
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
        data        = <<-YAML
# Promtail Configuration
server:
  http_listen_port: 9080
  log_level: info

# Where to send logs (uses Consul DNS for service discovery)
clients:
  - url: http://loki.service.consul:3100/loki/api/v1/push

# What to scrape
scrape_configs:
  # Scrape all journald logs
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
      
      # Extract Nomad job info from journald tag (if present)
      - source_labels: ['__journal_syslog_identifier']
        regex: '(.+)'
        target_label: 'syslog_identifier'
      
      # Add priority level
      - source_labels: ['__journal_priority']
        target_label: 'priority'

    # Pipeline stages to parse Nomad logs
    pipeline_stages:
      # Extract Nomad allocation info from container name in journald
      - regex:
          expression: '(?P<nomad_job>[a-zA-Z0-9_-]+)\.(?P<nomad_group>[a-zA-Z0-9_-]+)\.(?P<nomad_task>[a-zA-Z0-9_-]+)'
          source: syslog_identifier
      
      # Add extracted labels
      - labels:
          nomad_job:
          nomad_group:
          nomad_task:

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
