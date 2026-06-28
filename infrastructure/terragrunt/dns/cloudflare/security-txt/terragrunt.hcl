# -----------------------------------------------------------------------------
# CLOUDFLARE SECURITY.TXT LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_worker_routes" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-worker-routes.hcl"
  expose = true
}
