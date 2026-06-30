# -----------------------------------------------------------------------------
# CONSUL-KV ENV HELPER
# -----------------------------------------------------------------------------
#
# Composition for the generic consul-kv module. Path-keyed on the leaf dir name:
# each consuming leaf gets its own branch that assembles the keys map. The module
# stays generic; everything implementation-specific (which keys, what values)
# lives here.
#
#   github-token-renewer -> the newline-separated owner/repo list the
#   ghtokenrenewer worker reads at github/token-renewer/repos (REPO_LIST_KEY).
#
#   ci-runner-scaler -> the newline-separated owner/repo list the runnerscaler
#   worker watches for queued self-hosted jobs at runners/repos.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//consul-kv"
}

locals {
  leaf = basename(get_terragrunt_dir())

  # --- ghtokenrenewer: repos it mints GitHub App tokens into ---
  github_token_renewer_repos = [
    "afreidah/munchbox",
    "afreidah/s3-orchestrator",
    "afreidah/nomad-temporal-jobs",
    "afreidah/g3",
    "afreidah/cloudflare-log-collector",
    "afreidah/oracle-watchdog",
  ]

  # --- ci-runner-scaler: repos watched for queued self-hosted jobs. Trim to
  #     the repos that actually use `runs-on: [self-hosted]`. ---
  runner_scaler_repos = [
    "afreidah/munchbox",
    "afreidah/nomad-temporal-jobs",
  ]

  keys = (
    local.leaf == "github-token-renewer" ? {
      "github/token-renewer/repos" = join("\n", local.github_token_renewer_repos)
      } : local.leaf == "ci-runner-scaler" ? {
      "runners/repos" = join("\n", local.runner_scaler_repos)
    } : {}
  )
}

inputs = {
  keys = local.keys
}
