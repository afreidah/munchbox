# -----------------------------------------------------------------------------
# ACCESS-KEYS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "access-keys" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/access-keys.hcl"
  expose = true
}
