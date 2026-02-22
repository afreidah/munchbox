# -----------------------------------------------------------------------------
# CLOUDFLARE R2 ENV HELPER
# -----------------------------------------------------------------------------
#
# Creates Cloudflare R2 object storage buckets.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules/cloudflare-r2"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.cloudflare_r2_inputs
