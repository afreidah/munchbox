# -----------------------------------------------------------------------------
# CINC-SERVER-KEYS MODULE
# -----------------------------------------------------------------------------
#
# Generates a password and an RSA keypair per cinc-server user. The public half
# is installed at user-create time via `--user-key`, so the private half never
# exists on the server and never has to be captured off it. Vault-free: the
# values are a sensitive vault_data output written to Vault by the vault-secrets
# leaf.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "random_password" "user" {
  for_each = var.users

  length = each.value.password_length
  # --- alphanumeric: the password is passed as a chef-server-ctl argv element ---
  special = false
}

# --- RSA: the Chef Server API authenticates by RSA request signing, and the
#     server's own keygen is 2048-bit, so that is the compatible default. ---
resource "tls_private_key" "user" {
  for_each = var.users

  algorithm = "RSA"
  rsa_bits  = each.value.rsa_bits
}
