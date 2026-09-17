# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR ENV HELPER
# -----------------------------------------------------------------------------
#
# Declares the identities the homelab's s3-orchestrator authorizes requests
# against, one per process rather than one per bucket. Each gets a user, a
# minted keypair written to Vault, and a grant naming the one bucket it reaches.
#
# These replace the credentials the orchestrator's job file declares inline.
# Config-declared credentials always hold full access to their bucket and the
# admin API refuses to change them, so anything that should be narrowed or
# revoked without editing the job belongs here instead.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//s3-orchestrator"
}

locals {
  # --- one identity per process, each scoped to the single bucket it uses ---
  #
  # delete is granted where the process rewrites rather than only appends:
  # backup retention prunes, aptly republishes indices in place, and Tempo's
  # compactor removes the blocks it has merged.
  identities = {
    "temporal-backups-worker" = {
      label  = "temporal backup worker"
      grants = [{ name = "unified", permissions = ["list", "read", "write", "delete"] }]
    }
    "aptly" = {
      label  = "aptly debian repositories"
      grants = [{ name = "aptly", permissions = ["list", "read", "write", "delete"] }]
    }
    "tempo" = {
      label  = "tempo trace storage"
      grants = [{ name = "tempo-traces", permissions = ["list", "read", "write", "delete"] }]
    }
    # --- artifacts has one writer and one reader today; anything else that
    #     writes there gets its own named identity rather than sharing ---
    "artifacts_s3o_writer" = {
      label  = "s3-orchestrator release artifacts"
      grants = [{ name = "artifacts", permissions = ["list", "read", "write"] }]
    }
    # tags is carried because terraform's aws_s3_object data source fetches an
    # object's tags whenever it reads one, and the orchestrator authorizes all
    # three tagging verbs under the one permission.
    "artifacts_terragrunt_reader" = {
      label  = "terragrunt artifact consumer"
      grants = [{ name = "artifacts", permissions = ["list", "read", "tags"] }]
    }

    # --- a human's credential, and what munchbox-env.sh exports. Carries root's
    #     grant set so it can do everything root can, but as a store row that
    #     can be revoked or narrowed. Root stays: it is templated from config
    #     rather than stored, so it survives a database this one does not. ---
    "admin" = {
      label = "interactive and env-file admin"
      grants = [
        { kind = "bucket", name = "*", permissions = ["all"] },
        { kind = "backend", name = "*", permissions = ["admin-all"] },
        { kind = "orchestrator", permissions = ["admin-all"] },
      ]
    }
  }
}

inputs = {
  address    = "https://s3.munchbox.cc"
  identities = local.identities
}
