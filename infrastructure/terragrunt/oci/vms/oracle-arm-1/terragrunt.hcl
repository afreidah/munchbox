# -----------------------------------------------------------------------------
# OCI NODE - oracle-arm-1
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "bootstrap" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/bootstrap.hcl"
  expose = true
}
