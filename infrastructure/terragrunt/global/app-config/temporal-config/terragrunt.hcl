# -----------------------------------------------------------------------------
# TEMPORAL CONFIG LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "temporal" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/temporal.hcl"
  expose = true
}
