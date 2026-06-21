# -----------------------------------------------------------------------------
# VAULT SECRETS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "vault_secrets" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/vault-secrets.hcl"
  expose = true
}
