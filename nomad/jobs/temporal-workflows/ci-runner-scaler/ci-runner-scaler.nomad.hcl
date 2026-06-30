# -------------------------------------------------------------------------------
# CI Runner Scaler - Temporal On-Demand GitHub Actions Runner Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# Temporal worker that scales self-hosted CI runners on demand (zero idle). One
# task queue (ci-runner-scaler-task-queue), two workflows started by a Temporal
# Schedule (managed in infrastructure/terragrunt):
#   * PollAndDispatch (~30s): lists each watched repo's queued self-hosted Actions
#     jobs and starts one HandleQueuedJob child per job, keyed
#     runner-<repo>-<job_id> with a reject-duplicate ID policy (Temporal dedups
#     one runner per job; no external state store).
#   * HandleQueuedJob: mints a runner registration token and dispatches one
#     ephemeral ci-runner for the job, then reaps it via a backstop timer.
#
# Self-authenticating: the task carries only its Workload Identity. The vault{}
# block exchanges the WI for a Vault token at /secrets/vault_token (the worker
# reads the GitHub App key through it); the default WI is exposed as NOMAD_TOKEN
# (identity.env) and authorizes the Nomad API via its associated ACL policy. The
# watched repos + profiles come from Consul KV (the local agent's default token).
#
# Requires (infrastructure/terragrunt):
#   * vault-config:  policy "ci-runner-scaler" (read secret/github/token-renewer-app)
#                    + workload_vault_role "ci-runner-scaler" (bound_claims job_id)
#   * nomad workload-identity ACL policy bound to job "ci-runner-scaler" granting
#     dispatch-job + read-job + submit-job on the namespace
#   * consul-kv:     "runners/repos" = newline owner/repo list,
#                    "runners/profiles" = JSON label->{image} map
#   * The token-renewer GitHub App must grant Administration + Actions (github.com)
# -------------------------------------------------------------------------------

job "ci-runner-scaler" {
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
      # Host stub resolver so .consul (vault/temporal/tempo/consul/nomad) and
      # public names (api.github.com) both resolve. Mirrors the other workers.
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
      name     = "ci-runner-scaler"
      port     = "metrics"
      provider = "consul"

      tags = [
        "temporal",
        "ci-runner-scaler",
        "traefik.enable=false",
      ]

      # --- HTTP check on the metrics endpoint: the distroless image has no shell
      #     for a script check, and a live /metrics is a stronger liveness signal
      #     than process presence anyway. ---
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
    # Task: ci-runner-scaler
    # -------------------------------------------------------------------------

    task "ci-runner-scaler" {
      driver = "docker"

      # --- WI: job_id "ci-runner-scaler" matches bound_claims on this role,
      #     granting nomad-workloads plus the ci-runner-scaler policy (read the
      #     GitHub App key). Role + policy are in infrastructure/terragrunt
      #     vault-config. ---
      vault {
        role = "ci-runner-scaler"
      }

      # env=true exposes the default WI as NOMAD_TOKEN; the Nomad API accepts it
      # and resolves the dispatch ACL policy bound to this job.
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/ci-runner-scaler:latest"
        force_pull         = true
        image_pull_timeout = "10m"
        network_mode       = "host"
        ports              = ["metrics"]
        volumes = [
          # The pki_int intermediate signs both the Vault and Nomad server certs,
          # so one CA file backs VAULT_CACERT and NOMAD_CACERT.
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/munchbox-ca.pem:ro",
        ]
      }

      env {
        TEMPORAL_ADDRESS            = "temporal-server.service.consul:7233"
        METRICS_LISTEN              = ":${NOMAD_PORT_metrics}"
        OTEL_EXPORTER_OTLP_ENDPOINT = "tempo.service.consul:4317"

        # Vault (runtime client): reads the GitHub App key via the WI token.
        VAULT_ADDR       = "https://vault.service.consul:8200"
        VAULT_CACERT     = "/etc/ssl/certs/munchbox-ca.pem"
        VAULT_TOKEN_FILE = "/secrets/vault_token"

        # Nomad (job dispatch): NOMAD_TOKEN is the default WI (identity.env).
        NOMAD_ADDR            = "https://192.168.68.61:4646"
        NOMAD_TLS_SERVER_NAME = "server.global.nomad"
        NOMAD_CACERT          = "/etc/ssl/certs/munchbox-ca.pem"

        # GitHub App + Consul KV locations + the dispatched runner job. These match
        # the worker's built-in defaults; set here for visibility. The KV reads use
        # the local Consul agent's default ACL token (host networking).
        GITHUB_APP_VAULT_PATH = "github/token-renewer-app"
        RUNNERS_REPOS_KEY     = "runners/repos"
        RUNNERS_PROFILES_KEY  = "runners/profiles"
        RUNNER_JOB_ID         = "ci-runner"
      }

      # --- Light: a handful of HTTP calls per repo per tick (Consul KV, GitHub
      #     list/mint, Nomad dispatch). ---
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
