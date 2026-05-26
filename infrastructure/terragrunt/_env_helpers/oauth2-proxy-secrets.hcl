# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Wires Google OAuth credentials (from shell env, sourced by munchbox-env.sh
# out of Vault) plus the allowed-emails list from root.hcl into the module.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/oauth2-proxy-secrets"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  vault_mount    = "secret"
  client_id      = get_env("OAUTH2_PROXY_CLIENT_ID", "")
  client_secret  = get_env("OAUTH2_PROXY_CLIENT_SECRET", "")
  cookie_secret  = get_env("OAUTH2_PROXY_COOKIE_SECRET", "")
  allowed_emails = local.root.locals.oauth2_proxy_allowed_emails
}
