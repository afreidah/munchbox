# -----------------------------------------------------------------------------
# FORGEJO SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Syncs secrets from Vault to Forgejo repository action secrets for CI/CD.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules/forgejo-secrets"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.forgejo_secrets_inputs
