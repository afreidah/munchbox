include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "forgejo_secrets" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/forgejo-secrets.hcl"
  expose = true
}
