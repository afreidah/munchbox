# -----------------------------------------------------------------------------
# CLOUDFLARE WEB ANALYTICS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_web_analytics" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-web-analytics.hcl"
  expose = true
}
