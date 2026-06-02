# -----------------------------------------------------------------------------
# APTLY SECRETS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "aptly_secrets" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/aptly-secrets.hcl"
  expose = true
}
