# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Syncs credentials from HashiCorp Vault to Vaultwarden for human access.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/vaultwarden-secrets"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.vaultwarden_secrets_inputs
