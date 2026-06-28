# -----------------------------------------------------------------------------
# CLOUDFLARE WAF LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_waf" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-waf.hcl"
  expose = true
}
