# -----------------------------------------------------------------------------
# APTLY SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates the aptly API admin password + bcrypt htpasswd. Vault-free: the
# values are written to Vault by the aptly-admin-secret leaf via dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//aptly-secrets"
}

inputs = {
  username = "admin"
}
