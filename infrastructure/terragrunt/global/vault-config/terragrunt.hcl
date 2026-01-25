include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "vault_config" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/vault-config.hcl"
  expose = true
}
