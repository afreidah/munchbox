# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages Google OAuth credentials for oauth2-proxy in Vault.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules/oauth2-proxy-secrets"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.oauth2_proxy_secrets_inputs
