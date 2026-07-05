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
#   ci-runner-scaler -> the JSON per-repo provisioning config the runnerscaler
#   worker reads at runners/config. Each repo picks a mode: "app" (poll the
#   GitHub App, mint a registration token per dispatch) or "vault" (poll with a
#   PAT from the secret store, dispatch a self-registering job that mints
#   nothing), with an optional ordered label->job profile list.
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

  # --- ci-runner-scaler: per-repo provisioning config. app-mode repos are polled
  #     and minted through the shared GitHub App; ev-the-dev/moat is not ours, so
  #     the App can't be installed on it -- it is vault-mode, polled and
  #     self-registered from the PAT already stored at secret/github/moat-runner
  #     (the same one the static moat runners use). Its profiles map the
  #     distinguishing runs-on label to the parameterized runner job, evaluated
  #     top-down (first matching label wins): `vm` -> KVM pool, `go` -> the lean
  #     shared go-ci-runner (moat's Go CI once ci.yml carries a `go` label), and
  #     `moat` -> the heavy Cinc pool (chef.yml et al). `vm` is first so a job
  #     carrying both `vm` and another label still lands on the KVM pool. Object
  #     literal (not tomap) so the app/vault entries keep their own shapes through
  #     jsonencode. ---
  runner_scaler_config = {
    "afreidah/munchbox"            = { mode = "app" }
    "afreidah/nomad-temporal-jobs" = { mode = "app" }
    # poll/register split: we're only write on moat, so poll with a low-priv PAT
    # and register with the owner's admin PAT.
    "ev-the-dev/moat" = {
      mode              = "vault"
      vaultPath         = "github/moat-poll"
      registerVaultPath = "github/moat-runner"
      # maxConcurrent caps each pool; vm is pinned to the two KVM hosts, so keep it low.
      profiles = [
        { label = "vm", job = "github-runner-moat-vm", maxConcurrent = 2 },
        { label = "go", job = "go-ci-runner", maxConcurrent = 6 },
        { label = "moat", job = "github-runner-moat", maxConcurrent = 3 },
      ]
    }
  }

  keys = (
    local.leaf == "github-token-renewer" ? {
      "github/token-renewer/repos" = join("\n", local.github_token_renewer_repos)
      } : local.leaf == "ci-runner-scaler" ? {
      "runners/config" = jsonencode(local.runner_scaler_config)
    } : {}
  )
}

inputs = {
  keys = local.keys
}
