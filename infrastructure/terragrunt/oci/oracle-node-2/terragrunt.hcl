# -----------------------------------------------------------------------------
# OCI NODE - oracle-node-2 (shares network with oracle-node-1 via node.yaml)
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "bootstrap" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/bootstrap.hcl"
  expose = true
}
