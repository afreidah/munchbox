# -----------------------------------------------------------------------------
# GOSSIP KEYS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "gossip_keys" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/gossip-keys.hcl"
  expose = true
}
