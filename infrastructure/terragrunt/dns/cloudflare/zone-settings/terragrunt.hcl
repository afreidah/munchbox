# -----------------------------------------------------------------------------
# CLOUDFLARE ZONE SETTINGS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloudflare_zone_settings" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloudflare-zone-settings.hcl"
  expose = true
}
