# -----------------------------------------------------------------------------
# APTLY-SECRETS MODULE
# -----------------------------------------------------------------------------
#
# Generates the aptly API basic-auth credentials: a random admin password and
# its apr1 htpasswd line. apr1 (nginx-native) is used over bcrypt so auth_basic
# verification stays fast on every authenticated API call. Vault-free: values
# are exposed as a sensitive vault_data output and written to Vault by a
# separate consumer leaf via a terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "random_password" "admin" {
  length  = 32
  special = false
}

# --- apr1 salt: exactly 8 chars from the crypt base64 alphabet ---
resource "random_password" "salt" {
  length           = 8
  special          = true
  override_special = "./"
}

resource "htpasswd_password" "admin" {
  password = random_password.admin.result
  salt     = random_password.salt.result
}
