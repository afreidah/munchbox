# -----------------------------------------------------------------------------
# Nomad ACLs - Policies and Tokens
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "nomad_acls" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/nomad-acls.hcl"
  expose = true
}
