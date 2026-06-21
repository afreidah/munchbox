include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "vaultwarden_secrets" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/vaultwarden-secrets.hcl"
  expose = true
}
