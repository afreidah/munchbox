include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "oauth2_proxy_secrets" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/oauth2-proxy-secrets.hcl"
  expose = true
}
