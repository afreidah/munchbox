# -------------------------------------------------------------------------------
# Trivy Scan Worker - Temporal Vulnerability Scanner
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that scans all running container images for vulnerabilities
# using Trivy server mode. Stores CVE results in PostgreSQL. Listens on the
# trivy-task-queue; workflows are started on schedule by a Temporal Schedule.
# -------------------------------------------------------------------------------

job "trivy-scan-worker" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Placement - off the ingress nodes (don't compete with the DB/haproxy there)
  # and off cloud nodes (needs reliable LAN access to the Trivy server).
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "!="
    value     = "ingress"
  }

  constraint {
    attribute = "${meta.cloud}"
    operator  = "!="
    value     = "oracle"
  }

  # ---------------------------------------------------------------------------
  # Task Group: worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    network {
      port "metrics" {
        to = 9090
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # --- Service registration for Prometheus scraping ---
    service {
      name     = "trivy-scan-worker"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "scanner",
        "traefik.enable=false",
      ]

      check {
        name      = "worker-alive"
        type      = "script"
        command   = "/bin/sh"
        args      = ["-c", "pgrep -f trivy-scan-worker"]
        interval  = "30s"
        timeout   = "5s"
        task      = "trivy-scan-worker"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: trivy-scan-worker
    # -------------------------------------------------------------------------

    task "trivy-scan-worker" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/trivy-scan-worker:v0.3.0"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes            = [
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/nomad-ca.pem:ro",
          "secrets/postgres-ca.crt:/etc/ssl/postgres/ca.crt:ro",
        ]
      }

      # --- PostgreSQL CA certificate for TLS verification ---
      template {
        destination = "secrets/postgres-ca.crt"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "pki_int/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
        EOF
      }

      # --- Secrets from Vault ---
      template {
        data = <<-EOF
        {{ with secret "secret/data/backup-worker" }}
        NOMAD_TOKEN={{ .Data.data.nomad_token }}
        {{ end }}
        {{ with secret "secret/data/trivy-dashboard" }}
        TRIVY_DB_USER={{ .Data.data.db_username }}
        TRIVY_DB_PASSWORD={{ .Data.data.db_password }}
        {{ end }}
        EOF
        destination = "secrets/secrets.env"
        env         = true
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        NOMAD_ADDR                  = "https://192.168.68.61:4646"
        NOMAD_TLS_SERVER_NAME       = "server.global.nomad"
        NOMAD_CACERT                = "/etc/ssl/certs/nomad-ca.pem"
        TRIVY_DB_HOST               = "haproxy-postgres.service.consul"
        TRIVY_DB_PORT               = "5433"
        TRIVY_DB_NAME               = "trivy"
        DB_SSLMODE                  = "verify-ca"
        DB_SSLROOTCERT              = "/etc/ssl/postgres/ca.crt"
        METRICS_LISTEN              = ":9090"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
