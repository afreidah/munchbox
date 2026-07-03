# -------------------------------------------------------------------------------
# CI Runner — on-demand ephemeral GitHub Actions runner (parameterized)
#
# Project: Munchbox / Author: Alex Freidah
#
# A parameterized batch job: each dispatch spawns one EPHEMERAL self-hosted
# runner (takes a single job, then deregisters and exits) from the thin
# registry.munchbox.cc/ci-runner image. Used for cluster-side CI that can't run
# on GitHub-hosted runners (terragrunt validate/plan, trivy/checkov, nomad job
# validate). Dispatched per queued workflow_job by the Temporal poller, which
# mints the per-run registration token and passes it as meta.
#
#   nomad job run ci-runner.nomad.hcl        # register the parameterized job
#   nomad job dispatch \                     # spawn one runner
#     -meta repo_url=https://github.com/afreidah/munchbox \
#     -meta runner_token=<registration-token> \
#     -meta labels=self-hosted,tf-deep \
#     ci-runner
#
# Cluster creds: the task carries a Workload Identity, exchanged via vault{} for a
# Vault token, which the template below uses to read a scoped Nomad ACL token
# (submit-job) as NOMAD_TOKEN — enough for `nomad job validate`/`plan`. terragrunt
# validate needs no secrets. Role + policy + token live in infrastructure/terragrunt
# (_env_helpers/vault-config.hcl + nomad-acls.hcl); apply those before registering
# this job so the WI role and secret/ci-runner-nomad exist.
# -------------------------------------------------------------------------------

job "ci-runner" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "default"

  # --- Dispatched per CI run; meta carries the target repo + minted token ---
  parameterized {
    meta_required = ["repo_url", "runner_token"]
    meta_optional = ["labels"]
  }

  # --- Default labels when a dispatch omits them ---
  meta {
    labels = "self-hosted"
  }

  group "runner" {
    count = 1

    # --- amd64-only image; keep it off arm64 nodes (Pi5s) where it can't run ---
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

      # --- WI exchanged for a Vault token so the template below can read the
      #     scoped Nomad ACL token. Role + policy live in terragrunt vault-config. ---
      vault {
        role = "ci-runner"
      }

      # The default WI (identity.env) carries no Nomad policy; the scoped
      # NOMAD_TOKEN templated in below overrides it.
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image = "registry.munchbox.cc/ci-runner:latest"
        # force_pull so a rebuilt :latest (e.g. a tool version bump) is picked up
        # on the next dispatch instead of a stale cached image.
        force_pull         = true
        image_pull_timeout = "10m"
        volumes = [
          # pki_int signs the Nomad server cert; this CA backs NOMAD_CACERT.
          "/opt/nomad/tls/vault-intermediate-ca.pem:/etc/ssl/certs/munchbox-ca.pem:ro",
        ]
      }

      # --- Scoped Nomad ACL token (submit-job) for `nomad job validate`/`plan`.
      #     Minted by terragrunt nomad-acls -> secret/ci-runner-nomad. ---
      template {
        data        = <<-EOF
        {{ with secret "secret/data/ci-runner-nomad" }}
        NOMAD_TOKEN={{ .Data.data.nomad_token }}
        {{ end }}
        EOF
        destination = "secrets/nomad.env"
        env         = true
      }

      env {
        RUNNER_SCOPE        = "repo"
        REPO_URL            = "${NOMAD_META_repo_url}"
        RUNNER_TOKEN        = "${NOMAD_META_runner_token}"
        LABELS              = "${NOMAD_META_labels}"
        EPHEMERAL           = "true"
        DISABLE_AUTO_UPDATE = "true"
        RUN_AS_ROOT         = "false"
        RUNNER_NAME         = "ci-runner-${NOMAD_ALLOC_ID}"
        RUNNER_WORKDIR      = "/tmp/runner-work"

        # --- Nomad API for `nomad job validate`/`plan`; NOMAD_TOKEN from template ---
        NOMAD_ADDR            = "https://192.168.68.61:4646"
        NOMAD_TLS_SERVER_NAME = "server.global.nomad"
        NOMAD_CACERT          = "/etc/ssl/certs/munchbox-ca.pem"
      }

      # --- Ephemeral one-shot, so a flat reservation has no idle cost (no need
      #     for memory_max/oversubscription) ---
      resources {
        cpu    = 2000
        memory = 2048
      }
    }
  }
}
