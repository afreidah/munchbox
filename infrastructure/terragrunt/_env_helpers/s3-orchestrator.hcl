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
      bucket      = "unified"
      permissions = ["list", "read", "write", "delete"]
      label       = "temporal backup worker"
    }
    "aptly" = {
      bucket      = "aptly"
      permissions = ["list", "read", "write", "delete"]
      label       = "aptly debian repositories"
    }
    "tempo" = {
      bucket      = "tempo-traces"
      permissions = ["list", "read", "write", "delete"]
      label       = "tempo trace storage"
    }
    # --- artifacts has one writer and one reader today; anything else that
    #     writes there gets its own named identity rather than sharing ---
    "artifacts_s3o_writer" = {
      bucket      = "artifacts"
      permissions = ["list", "read", "write"]
      label       = "s3-orchestrator release artifacts"
    }
    "artifacts_terragrunt_reader" = {
      bucket      = "artifacts"
      permissions = ["list", "read"]
      label       = "terragrunt artifact consumer"
    }
  }
}

inputs = {
  address    = "https://s3.munchbox.cc"
  identities = local.identities
}
