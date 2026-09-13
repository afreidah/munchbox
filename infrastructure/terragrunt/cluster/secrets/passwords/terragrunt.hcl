# -----------------------------------------------------------------------------
# PASSWORDS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "passwords" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/passwords.hcl"
  expose = true
}
