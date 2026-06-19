# -------------------------------------------------------------------------------
# Cert Acquirer Worker - Temporal Wildcard Certificate Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that issues the *.munchbox.cc wildcard via ACME DNS-01
# (Cloudflare) and publishes the cert+key to secret/traefik/wildcard for both
# Traefiks to read. Listens on the cert-task-queue; the workflow is started on
# schedule by a Temporal Schedule (managed in infrastructure/terragrunt).
#
# Self-authenticating: the task carries only its Workload Identity. Nomad writes
# the WI Vault token to /secrets/vault_token (vault{} block below) and the worker
# pulls the Cloudflare token + persists the ACME account through Vault itself --
# no secrets are templated into the job.
# -------------------------------------------------------------------------------

job "cert-acquirer-worker" {
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
  # Task Group: worker
  # ---------------------------------------------------------------------------

  group "worker" {
    count = 1

    network {
      # Host stub resolver so .consul (vault/temporal/tempo) and public names
      # (Let's Encrypt, Cloudflare) both resolve. Mirrors the other workers.
      dns {
        servers  = ["127.0.0.53"]
        searches = []
      }
      # --- Dynamic host port (host networking): the worker binds it via
      #     METRICS_LISTEN below, so it never collides with the node's :9090. ---
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
      name     = "cert-acquirer-worker"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "cert-acquirer",
        "traefik.enable=false",
      ]

      # --- HTTP check on the metrics endpoint: the distroless image has no
      #     shell for a pgrep script check, and a live /metrics is a stronger
      #     liveness signal than process presence anyway. ---
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
    # Task: cert-acquirer-worker
    # -------------------------------------------------------------------------

    task "cert-acquirer-worker" {
      driver = "docker"

      # --- WI: job_id "cert-acquirer-worker" matches bound_claims on this role,
      #     granting nomad-workloads (read, incl. cloudflare-wandns) plus
      #     cert-acquirer-worker (write wildcard/staging/acme-account). ---
      vault {
        role = "cert-acquirer-worker"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/cert-acquirer-worker:latest"
        force_pull         = true
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes = [
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/vault-ca.pem:ro",
        ]
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        VAULT_ADDR                  = "https://vault.service.consul:8200"
        VAULT_CACERT                = "/etc/ssl/certs/vault-ca.pem"
        VAULT_TOKEN_FILE            = "/secrets/vault_token"
        METRICS_LISTEN              = ":${NOMAD_PORT_metrics}"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"
      }

      # --- lego is light; it proxies DNS-01 to Cloudflare and waits on
      #     propagation, so CPU/memory stay small. ---
      resources {
        cpu    = 200
        memory = 192
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
