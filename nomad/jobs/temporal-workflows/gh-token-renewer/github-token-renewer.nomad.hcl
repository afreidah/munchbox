# -------------------------------------------------------------------------------
# GitHub Token Renewer - Temporal CI-Token Renewal Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that keeps every managed repo's CI/release token secret
# continuously valid: it mints a short-lived GitHub App installation token per
# repo and writes it to the repo's RELEASE_PAT Actions secret, so the token
# never expires (replacing hand-rotated PATs). Listens on the
# github-token-renewer-task-queue; the RenewTokens workflow is started on
# schedule by a Temporal Schedule (managed in infrastructure/terragrunt).
#
# Self-authenticating: the task carries only its Workload Identity. Nomad writes
# the WI Vault token to /secrets/vault_token (vault{} block below); the worker
# reads the GitHub App private key through Vault and the repo list from Consul KV
# (the local agent's default token) -- no secrets are templated into the job.
#
# Requires (infrastructure/terragrunt):
#   * vault-config:  policy "github-token-renewer" (read secret/github/token-renewer-app)
#                    + workload_vault_role "github-token-renewer" (bound_claims job_id)
#   * consul-kv:     "github/token-renewer/repos" = newline-separated owner/repo list
# -------------------------------------------------------------------------------

job "github-token-renewer" {
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
      # Host stub resolver so .consul (vault/temporal/tempo/consul) and public
      # names (api.github.com) both resolve. Mirrors the other workers.
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
      name     = "github-token-renewer"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "github-token-renewer",
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
    # Task: github-token-renewer
    # -------------------------------------------------------------------------

    task "github-token-renewer" {
      driver = "docker"

      # --- WI: job_id "github-token-renewer" matches bound_claims on this role,
      #     granting nomad-workloads plus the github-token-renewer policy (read
      #     secret/github/token-renewer-app). Role + policy are defined in
      #     infrastructure/terragrunt vault-config. ---
      vault {
        role = "github-token-renewer"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/github-token-renewer:latest"
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

        # GitHub App credentials + the managed-repo list + target secret. These
        # match the worker's built-in defaults; set here for visibility. The
        # repo-list KV read uses the local Consul agent's default ACL token (host
        # networking), so no Consul token is templated in.
        GITHUB_APP_VAULT_PATH = "github/token-renewer-app"
        REPO_LIST_KEY         = "github/token-renewer/repos"
        SECRET_NAME           = "RELEASE_PAT"
      }

      # --- Light: a handful of HTTP calls per repo (Consul KV, Vault, GitHub
      #     mint + set-secret). ---
      resources {
        cpu    = 150
        memory = 128
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
