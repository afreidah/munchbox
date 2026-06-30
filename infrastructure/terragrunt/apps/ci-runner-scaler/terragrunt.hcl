# -----------------------------------------------------------------------------
# CI RUNNER SCALER REPOS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "consul_kv" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/consul-kv.hcl"
  expose = true
}
