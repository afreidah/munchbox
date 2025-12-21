# -------------------------------------------------------------------------------
# Temporal Backup Worker — Distributed Backup Execution Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that executes backup workflows for cluster services. Handles
# PostgreSQL dumps, registry snapshots, and uploads to Google Drive storage.
# -------------------------------------------------------------------------------

job "temporal-backup-worker" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------


  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------

  #constraint {
  #  attribute = "${node.unique.name}"
  #  value     = "mccoy"
  #}

  # ---------------------------------------------------------------------------
  # Task Group: worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
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
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "temporal-backup-worker"
      provider = "consul"

      tags = [
        "backup",
        "temporal",
      ]

      check {
        name     = "worker-alive"
        type     = "script"
        command  = "/bin/sh"
        args     = ["-c", "pgrep -f temporal-backup-worker"]
        interval = "30s"
        timeout  = "5s"
        task     = "backup-worker"
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
        image              = "registry.munchbox.cc/temporal-backup-worker:latest"
        image_pull_timeout = "10m"
        args               = ["worker"]
        network_mode       = "host"
        volumes            = [
          "/mnt/gdrive:/mnt/gdrive",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/nomad-ca.pem:ro",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/vault-ca.pem:ro"
        ]
        dns_servers        = ["192.168.68.64", "192.168.68.62"]
      }

      template {
        data = <<-EOF
        {{ with secret "secret/data/backup-worker" }}
        NOMAD_TOKEN={{ .Data.data.nomad_token }}
        CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
        {{ end }}
        {{ with secret "secret/data/postgres-shared/root" }}
        PGPASSWORD={{ .Data.data.password }}
        {{ end }}
        {{ with secret "secret/data/trivy-dashboard" }}
        TRIVY_DB_USER={{ .Data.data.db_username }}
        TRIVY_DB_PASSWORD={{ .Data.data.db_password }}
        {{ end }}
        {{ with secret "secret/data/redis-shared" }}
        REDIS_PASSWORD={{ .Data.data.password }}
        {{ end }}
        EOF
        destination = "secrets/secrets.env"
        env         = true
      }

      env {
        TEMPORAL_ADDRESS  = "temporal-server.service.consul:7233"
        NOMAD_ADDR        = "https://nomad.service.consul:4646"
        NOMAD_CACERT      = "/etc/ssl/certs/nomad-ca.pem"
        VAULT_CACERT      = "/etc/ssl/certs/vault-ca.pem"
        TRIVY_DB_HOST     = "postgres-primary.service.consul"
        TRIVY_DB_PORT     = "5432"
        TRIVY_DB_NAME     = "trivy"
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "http://tempo.service.consul:4317"
        OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
      }

      # --- Resources ---
      # Note: Registry backup tars ~600MB of data, needs adequate memory for gzip
      resources {
        cpu    = 2000
        memory = 512
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "temporal-backup-worker"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
