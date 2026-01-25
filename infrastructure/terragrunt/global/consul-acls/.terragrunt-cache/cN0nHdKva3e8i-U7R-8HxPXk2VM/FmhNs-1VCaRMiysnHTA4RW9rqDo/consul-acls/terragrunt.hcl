# -----------------------------------------------------------------------------
# Consul ACLs - Policies and Tokens
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "consul_acls" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/consul-acls.hcl"
  expose = true
}
