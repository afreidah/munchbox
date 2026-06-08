include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "pihole-dns" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/pihole-dns.hcl"
  expose = true
}
