# -------------------------------------------------------------------------------
# Cleanup Worker - Temporal Orphaned Data Removal Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that cleans up orphaned Nomad job data directories on client
# nodes via SSH. Listens on the cleanup-task-queue; workflows are started on
# schedule by a Temporal Schedule (managed in infrastructure/terragrunt).
# -------------------------------------------------------------------------------

job "cleanup-worker" {
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
  # Placement - stabler only (bare metal node with SSH access to cluster).
  # Excluded from goren because cleanup-worker binds host:9090 in host-net
  # mode, which collides with the prometheus job on the ingress node.
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${node.unique.name}"
    value     = "stabler"
  }

  # ---------------------------------------------------------------------------
  # Task Group: worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    network {
      # --- Dynamic host port (host networking): the worker binds it via
      #     METRICS_LISTEN below, so the check hits the same port the worker
      #     listens on, and it never collides with the node's :9090. ---
      port "metrics" {}
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
      name     = "cleanup-worker"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "cleanup",
        "traefik.enable=false",
      ]

      # --- HTTP check on /metrics: the image is distroless now, so there is no
      #     shell for a pgrep script check, and a live /metrics is a stronger
      #     liveness signal than process presence anyway (matches cert-acquirer). ---
      check {
        name      = "metrics"
        type      = "http"
        port      = "metrics"
        path      = "/metrics"
        interval  = "30s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: cleanup-worker
    # -------------------------------------------------------------------------

    task "cleanup-worker" {
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
        image              = "registry.munchbox.cc/cleanup-worker:latest"
        force_pull         = true
        image_pull_timeout = "5m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes            = [
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/nomad-ca.pem:ro",
          "secrets/ssh-key:/root/.ssh/id_ed25519:ro",
          "secrets/ssh-client-cert.pub:/root/.ssh/id_ed25519-cert.pub:ro",
          "secrets/ssh-host-ca.pub:/root/.ssh/ssh-host-ca.pub:ro",
        ]
      }

      # --- SSH CA - backup worker private key from Vault KV ---
      template {
        destination = "secrets/ssh-key"
        perms       = "0600"
        data        = <<-EOF
{{ with secret "secret/data/ssh/backup-worker" }}
{{ .Data.data.private_key }}
{{ end }}
        EOF
      }

      # --- SSH CA - host CA public key (replaces known_hosts) ---
      template {
        destination = "secrets/ssh-host-ca.pub"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "ssh-host-signer/config/ca" }}
{{ .Data.public_key }}
{{ end }}
        EOF
      }

      # --- SSH CA - signed client certificate ---
      template {
        destination   = "secrets/ssh-client-cert.pub"
        perms         = "0644"
        change_mode   = "noop"
        data          = <<-EOF
{{ with secret "secret/data/ssh/backup-worker" }}{{ $pub := .Data.data.public_key }}{{ with secret "ssh-client-signer/sign/client-service" (printf "public_key=%s" $pub) "valid_principals=root,ubuntu" }}
{{ .Data.signed_key }}
{{ end }}{{ end }}
        EOF
      }

      # --- Secrets from Vault ---
      template {
        data = <<-EOF
        {{ with secret "secret/data/backup-worker" }}
        NOMAD_TOKEN={{ .Data.data.nomad_token }}
        {{ end }}
        {{ with secret "secret/data/postgres-shared/root" }}
        PGPASSWORD={{ .Data.data.password }}
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
        SSH_KEY_PATH                = "/root/.ssh/id_ed25519"
        SSH_CERT_PATH               = "/root/.ssh/id_ed25519-cert.pub"
        SSH_HOST_CA_PATH            = "/root/.ssh/ssh-host-ca.pub"
        PG_HOST                     = "postgres-primary.service.consul"
        PG_USER                     = "postgres"
        PG_SSLMODE                  = "prefer"
        METRICS_LISTEN              = ":${NOMAD_PORT_metrics}"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      # Bumped from 100/32: the worker now carries the moby Docker client, an
      # SFTP client, and gopsutil (host stats for worker heartbeats), and buffers
      # registry-GC / aptly container logs during those sagas. 32 MiB OOMs.
      resources {
        cpu    = 500
        memory = 256
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
