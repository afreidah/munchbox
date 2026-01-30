# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS MODULE
# -----------------------------------------------------------------------------
#
# Manages oauth2-proxy credentials in Vault. Stores Google OAuth client
# credentials and generates a random cookie secret for session encryption.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# COOKIE SECRET
# -----------------------------------------------------------------------------
# Generate a random 32-byte cookie secret for oauth2-proxy session encryption.
# Only used if an existing cookie_secret is not provided.

resource "random_bytes" "cookie_secret" {
  count  = var.cookie_secret == null || var.cookie_secret == "" ? 1 : 0
  length = 32
}

locals {
  cookie_secret = var.cookie_secret != null && var.cookie_secret != "" ? var.cookie_secret : random_bytes.cookie_secret[0].base64
}

# -----------------------------------------------------------------------------
# VAULT SECRET
# -----------------------------------------------------------------------------
# Store oauth2-proxy configuration in Vault for retrieval by the Nomad job.

resource "vault_kv_secret_v2" "oauth2_proxy" {
  mount = var.vault_mount
  name  = "oauth2-proxy"

  data_json = jsonencode({
    client_id      = var.client_id
    client_secret  = var.client_secret
    cookie_secret  = local.cookie_secret
    allowed_emails = join("\n", var.allowed_emails)
  })
}
