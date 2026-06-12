# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Wires Google OAuth credentials (from shell env, sourced by munchbox-env.sh
# out of Vault) plus the allowed-emails list into the module.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/oauth2-proxy-secrets"
}

locals {
  # --- SSO-allowed emails ---
  oauth2_proxy_allowed_emails = [
    "alex.freidah@gmail.com",
    "afreidah@gmail.com",
    "hart.koko@gmail.com",
  ]
}

inputs = {
  vault_mount    = "secret"
  client_id      = get_env("OAUTH2_PROXY_CLIENT_ID", "")
  client_secret  = get_env("OAUTH2_PROXY_CLIENT_SECRET", "")
  cookie_secret  = get_env("OAUTH2_PROXY_COOKIE_SECRET", "")
  allowed_emails = local.oauth2_proxy_allowed_emails
}
