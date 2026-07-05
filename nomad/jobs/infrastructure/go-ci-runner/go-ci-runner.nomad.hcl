# -------------------------------------------------------------------------------
# go-ci-runner — on-demand ephemeral GitHub Actions runner for Go repos (generic)
#
# Project: Munchbox / Author: Alex Freidah
#
# A parameterized batch job that runs one EPHEMERAL self-hosted runner on the
# lean go-ci-runner image (Go/Node/goreleaser/golangci-lint/sqlc/lintian, no
# Cinc/Packer/KVM, unprivileged, no Docker socket). It is repo-agnostic: the
# credential, repo, and labels all come from dispatch meta, so a single
# registered job serves every Go repo the Temporal ci-runner-scaler drives,
# regardless of provisioning mode:
#
#   * app-mode  -> the scaler mints a registration token and passes runner_token;
#                  the runner joins with it.
#   * vault-mode -> the scaler passes runner_secret (a Vault KV path under
#                   secret/data/); the runner reads that repo's PAT and
#                   self-registers, so no token ever transits Temporal/Nomad meta.
#                   The nomad-workloads Vault policy must grant read on that path.
#
# LABELS come straight from the queued job's runs-on (meta), so the runner
# advertises exactly what it was dispatched for -- it never accidentally matches
# another pool's jobs.
#
#   nomad job run go-ci-runner.nomad.hcl        # register the parameterized job
#   nomad job dispatch \                         # vault-mode (scaler does this)
#     -meta repo_url=https://github.com/ev-the-dev/moat \
#     -meta runner_secret=github/moat-runner \
#     -meta labels=self-hosted,go \
#     go-ci-runner
# -------------------------------------------------------------------------------

job "go-ci-runner" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "default"

  # --- Dispatched per queued Go job. Every field is meta-driven; a dispatch
  #     carries exactly one credential (runner_token for app-mode, runner_secret
  #     for vault-mode), so all are optional. ---
  parameterized {
    meta_optional = ["repo_url", "labels", "runner_token", "runner_secret"]
  }

  group "runner" {
    count = 1

    # amd64-only image; run on any amd64 node (these light jobs don't need the
    # beefy Cinc/VM hosts, so spread for concurrency).
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    network {
      mode = "host"
    }

    # --- One-shot: an ephemeral runner runs a single job then exits; never
    #     restart or reschedule a finished/failed runner ---
    restart {
      attempts = 0
      mode     = "fail"
    }

    reschedule {
      attempts  = 0
      unlimited = false
    }

    task "runner" {
      driver = "docker"

      # Needed only by vault-mode dispatches (to read runner_secret); harmless
      # for app-mode, which sets no runner_secret and reads no secret below.
      vault {
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # Unprivileged, no docker.sock: Go build/test/lint/package needs neither.
      # force_pull so a rebuilt :latest is picked up on the next dispatch.
      config {
        image              = "registry.munchbox.cc/go-ci-runner:latest"
        force_pull         = true
        image_pull_timeout = "10m"
      }

      env {
        TZ                   = "America/Los_Angeles"
        START_DOCKER_SERVICE = "false"
        RUN_AS_ROOT          = "false"
      }

      # --- Credential + identity, all from dispatch meta. app-mode sets
      #     runner_token (the runner joins with it); vault-mode sets runner_secret
      #     (the runner reads that repo's PAT as ACCESS_TOKEN and self-registers).
      #     Only the credential that was passed is written. ---
      template {
        data        = <<-EOF
{{- if env "NOMAD_META_runner_token" }}
RUNNER_TOKEN={{ env "NOMAD_META_runner_token" }}
{{- end }}
{{- if env "NOMAD_META_runner_secret" }}
{{- with secret (printf "secret/data/%s" (env "NOMAD_META_runner_secret")) }}
ACCESS_TOKEN="{{ .Data.data.token }}"
{{- end }}
{{- end }}
REPO_URL={{ env "NOMAD_META_repo_url" }}
RUNNER_NAME=go-ci-runner-{{ env "NOMAD_ALLOC_ID" }}
RUNNER_WORKDIR=/tmp/runner-work
RUNNER_SCOPE=repo
EPHEMERAL=true
LABELS={{ env "NOMAD_META_labels" }}
RUNNER_VERSION=latest
DISABLE_AUTO_UPDATE=true
EOF
        destination = "secrets/github.env"
        env         = true
        perms       = "0600"
        change_mode = "noop"
      }

      # Lean vs the Cinc pool's 6000/2176: enough for `go test -race
      # -coverpkg=./...` (race is memory-hungry) while letting several run at once.
      resources {
        cpu    = 3000
        memory = 4096
      }

      kill_timeout = "120s"
      kill_signal  = "SIGTERM"
    }
  }
}
