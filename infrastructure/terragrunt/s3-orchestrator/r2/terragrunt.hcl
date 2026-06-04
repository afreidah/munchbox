include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_r2" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-r2.hcl"
  expose = true
}
