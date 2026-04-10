# -------------------------------------------------------------------------------
# Cloudflare Log Collector - Analytics Ingestion
#
# Project: Munchbox / Author: Alex Freidah
#
# Polls the Cloudflare GraphQL Analytics API for firewall events and HTTP
# traffic statistics. Ships firewall events to Loki as structured JSON logs
# and exposes HTTP traffic metrics via Prometheus. Traces poll cycles with
# OpenTelemetry for Tempo correlation.
# -------------------------------------------------------------------------------

job "cloudflare-log-collector" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group
  # ---------------------------------------------------------------------------

  group "cloudflare-log-collector" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9102
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # --- Metrics Service (for Prometheus) ---
    service {
      name     = "cloudflare-log-collector"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "cloudflare-log-collector",
        "monitoring",
        "prometheus",
        "metrics"
      ]

      check {
        name     = "cloudflare-log-collector-health"
        type     = "http"
        port     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -----------------------------------------------------------------------
    # Task: cloudflare-log-collector
    # -----------------------------------------------------------------------

    task "cloudflare-log-collector" {
      driver = "docker"

      # --- Vault Integration (for Cloudflare API token) ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "registry.munchbox.cc/cloudflare-log-collector:v0.1.12"
        image_pull_timeout = "5m"
        network_mode       = "host"
        args               = ["-config", "/secrets/config.yaml"]
        volumes = [
          "secrets/config.yaml:/secrets/config.yaml:ro"
        ]
      }

      # --- Config template with Vault secrets ---
      template {
        destination = "secrets/config.yaml"
        change_mode = "restart"
        data        = <<-EOF
cloudflare:
  api_token: "{{ with secret "secret/data/cloudflare" }}{{ .Data.data.api_token }}{{ end }}"
  zones:
    - id: "bd3f7236466255155ab59b9d21cd88fd"
      name: "munchbox.cc"
    - id: "79e647e591f69cc27254bf4771464619"
      name: "alexfreidah.com"
  poll_interval: 1m
  backfill_window: 1h

loki:
  endpoint: "http://loki.service.consul:3100"
  tenant_id: "fake"
  batch_size: 100

metrics:
  listen: ":{{ env "NOMAD_PORT_http" }}"

tracing:
  enabled: true
  endpoint: "tempo.service.consul:4317"
  sample_rate: 1.0
  insecure: true

logging:
  level: "info"
  format: "json"
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
