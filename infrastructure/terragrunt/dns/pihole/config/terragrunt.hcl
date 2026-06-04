# -----------------------------------------------------------------------------
# PI-HOLE CONFIG LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "pihole-config" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/pihole-config.hcl"
  expose = true
}
