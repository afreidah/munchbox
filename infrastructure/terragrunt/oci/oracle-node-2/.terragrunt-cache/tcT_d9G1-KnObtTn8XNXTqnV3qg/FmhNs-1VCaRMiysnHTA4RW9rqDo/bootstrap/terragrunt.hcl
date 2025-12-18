# -----------------------------------------------------------------------------
# OCI NODE - oracle-node-2
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "bootstrap" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/bootstrap.hcl"
  expose = true
}

dependency "oracle_node_1" {
  config_path = "../oracle-node-1"
}

inputs = {
  existing_subnet_id         = dependency.oracle_node_1.outputs.subnet_id
  existing_security_group_id = dependency.oracle_node_1.outputs.security_group_id
}
