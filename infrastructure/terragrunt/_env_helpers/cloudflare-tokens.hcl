# -----------------------------------------------------------------------------
# CLOUDFLARE TOKENS ENV HELPER
# -----------------------------------------------------------------------------
#
# Mints scoped Cloudflare API tokens from root.hcl's cloudflare_token_requests
# map. The module is Vault-free: token values are exposed as outputs and
# written to Vault by separate consumer leaves via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-api-token"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  tokens = local.root.locals.cloudflare_token_requests
}
