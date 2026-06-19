include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "dns" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/dns.hcl"
  expose = true
}
