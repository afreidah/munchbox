# -----------------------------------------------------------------------------
# CLOUDFLARE TOKENS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_tokens" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-tokens.hcl"
  expose = true
}
