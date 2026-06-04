# -----------------------------------------------------------------------------
# PI-HOLE SHARED HOST CONFIG LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "remote-files" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/remote-files.hcl"
  expose = true
}
