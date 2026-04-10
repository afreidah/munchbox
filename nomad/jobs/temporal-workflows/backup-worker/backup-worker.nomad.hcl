# -------------------------------------------------------------------------------
# Backup Worker - Temporal Infrastructure Backup Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that executes backup workflows for Nomad, Consul, PostgreSQL,
# and the container registry. Snapshots are stored on /mnt/gdrive and uploaded
# to S3 for off-site redundancy. Listens on the backup-task-queue, triggered
# by the temporal-backup-trigger periodic job.
# -------------------------------------------------------------------------------

job "backup-worker" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

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
  # Placement - pinned to node with /mnt/gdrive access
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    value     = "nomad-client-03"
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
      name     = "backup-worker"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "backup",
        "traefik.enable=false",
      ]

      check {
        name      = "worker-alive"
        type      = "script"
        command   = "/bin/sh"
        args      = ["-c", "pgrep -f backup-worker"]
        interval  = "30s"
        timeout   = "5s"
        task      = "backup-worker"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: backup-worker
    # -------------------------------------------------------------------------

    task "backup-worker" {
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
        image              = "registry.munchbox.cc/backup-worker:v0.1.4"
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes            = [
          "/mnt/gdrive:/mnt/gdrive",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/nomad-ca.pem:ro",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/vault-ca.pem:ro",
        ]
      }

      # --- Secrets from Vault ---
      template {
        data = <<-EOF
        {{ with secret "secret/data/backup-worker" }}
        NOMAD_TOKEN={{ .Data.data.nomad_token }}
        {{ end }}
        {{ with secret "secret/data/consul/backup-worker-token" }}
        CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
        {{ end }}
        {{ with secret "secret/data/postgres-shared/root" }}
        PGPASSWORD={{ .Data.data.password }}
        {{ end }}
        {{ with secret "secret/data/s3-orchestrator" }}
        S3_ACCESS_KEY={{ .Data.data.access_key }}
        S3_SECRET_KEY={{ .Data.data.secret_key }}
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
        VAULT_CACERT                = "/etc/ssl/certs/vault-ca.pem"
        S3_ENDPOINT                 = "http://s3-orchestrator.service.consul:9000"
        S3_BUCKET                   = "unified"
        METRICS_LISTEN              = ":9090"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      # --- Resources ---
      # Registry backup tars ~600MB of data; needs memory for gzip
      resources {
        cpu    = 2000
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
