# -----------------------------------------------------------------------------
# APTLY-SECRETS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Vault-ready credentials keyed by username; inner keys are the Vault data keys (password feeds APTLY_PASS, htpasswd feeds the aptly nginx auth_basic_user_file)."
  value = {
    (var.username) = {
      password = random_password.admin.result
      htpasswd = "${var.username}:${htpasswd_password.admin.apr1}"
    }
  }
  sensitive = true
}
