# -----------------------------------------------------------------------------
# JELLYFIN CONFIG LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "jellyfin-config" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/jellyfin-config.hcl"
  expose = true
}
