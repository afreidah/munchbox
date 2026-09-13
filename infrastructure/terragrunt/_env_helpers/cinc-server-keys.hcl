# -----------------------------------------------------------------------------
# CINC-SERVER-KEYS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates the password + RSA keypair for each cinc-server user below. Vault-
# free: the values are exposed as outputs and written to Vault by the
# vault-secrets leaf via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cinc-server-keys"
}

locals {
  # --- key = cinc-server username. The cinc_server cookbook reads the password
  #     and installs the public half at user-create; Forgejo CI authenticates to
  #     the server with the private half. ---
  cinc_server_users = {
    "forgejo-ci" = {}
  }
}

inputs = {
  users = local.cinc_server_users
}
