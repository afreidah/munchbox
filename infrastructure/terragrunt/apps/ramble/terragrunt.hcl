# -----------------------------------------------------------------------------
# RAMBLE LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "ramble" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/ramble.hcl"
  expose = true
}
