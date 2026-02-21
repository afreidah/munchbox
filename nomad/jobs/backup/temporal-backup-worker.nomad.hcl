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

  constraint {
    attribute = "${node.unique.name}"
    value     = "nomad-client-03"
  }

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
          "/opt/nomad/data:/opt/nomad/data",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/nomad-ca.pem:ro",
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/vault-ca.pem:ro",
          "secrets/postgres-ca.crt:/etc/ssl/postgres/ca.crt:ro",
          "secrets/ssh-key:/root/.ssh/id_ed25519:ro",
          "secrets/ssh-client-cert.pub:/root/.ssh/id_ed25519-cert.pub:ro",
          "secrets/ssh-host-ca.pub:/root/.ssh/ssh-host-ca.pub:ro"
        ]
      }

      # PostgreSQL CA certificate for TLS verification
      template {
        destination = "secrets/postgres-ca.crt"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "pki_int/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
        EOF
      }

      # SSH CA - backup worker private key from Vault KV
      template {
        destination = "secrets/ssh-key"
        perms       = "0600"
        data        = <<-EOF
{{ with secret "secret/data/ssh/backup-worker" }}
{{ .Data.data.private_key }}
{{ end }}
        EOF
      }

      # SSH CA - host CA public key (replaces known_hosts)
      template {
        destination = "secrets/ssh-host-ca.pub"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "ssh-host-signer/config/ca" }}
{{ .Data.public_key }}
{{ end }}
        EOF
      }

      # SSH CA - signed client certificate for backup worker
      template {
        destination   = "secrets/ssh-client-cert.pub"
        perms         = "0644"
        data          = <<-EOF
{{ with secret "secret/data/ssh/backup-worker" }}{{ $pub := .Data.data.public_key }}{{ with secret "ssh-client-signer/sign/client-service" (printf "public_key=%s" $pub) "valid_principals=root,ubuntu" }}
{{ .Data.signed_key }}
{{ end }}{{ end }}
        EOF
      }

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
        {{ with secret "secret/data/trivy-dashboard" }}
        TRIVY_DB_USER={{ .Data.data.db_username }}
        TRIVY_DB_PASSWORD={{ .Data.data.db_password }}
        {{ end }}
        {{ with secret "secret/data/redis-shared" }}
        REDIS_PASSWORD={{ .Data.data.password }}
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
        TEMPORAL_ADDRESS  = "temporal-server.service.consul:7233"
        NOMAD_ADDR        = "https://nomad.service.consul:4646"
        NOMAD_CACERT      = "/etc/ssl/certs/nomad-ca.pem"
        VAULT_CACERT      = "/etc/ssl/certs/vault-ca.pem"
        SSH_KEY_PATH      = "/root/.ssh/id_ed25519"
        SSH_CERT_PATH     = "/root/.ssh/id_ed25519-cert.pub"
        SSH_HOST_CA_PATH  = "/root/.ssh/ssh-host-ca.pub"
        TRIVY_DB_HOST     = "haproxy-postgres.service.consul"
        TRIVY_DB_PORT     = "5433"
        TRIVY_DB_NAME     = "trivy"
        DB_SSLMODE        = "verify-ca"
        DB_SSLROOTCERT    = "/etc/ssl/postgres/ca.crt"
        # S3 off-site backup configuration
        S3_ENDPOINT        = "http://s3-orchestrator.service.consul:9000"
        S3_BUCKET           = "unified"
        S3_RETENTION_DAYS   = "30"
        LOCAL_RETENTION_DAYS = "7"
        # OpenTelemetry tracing to Tempo (gRPC)
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
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
