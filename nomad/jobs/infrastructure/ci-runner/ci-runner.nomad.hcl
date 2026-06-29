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
# NOTE: cluster credentials (Consul state token, Vault, Nomad token) for the
# deep-leg tools are NOT wired yet — added next via a Vault workload-identity
# template once the runner's Vault policy is defined.
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

      config {
        image = "registry.munchbox.cc/ci-runner:latest"
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
