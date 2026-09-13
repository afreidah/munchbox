# -----------------------------------------------------------------------------
# CINC-SERVER-KEYS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cinc-server-keys" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cinc-server-keys.hcl"
  expose = true
}
