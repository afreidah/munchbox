# -------------------------------------------------------------------------------
# VAULT-CONFIG ENV HELPER
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures Vault secrets engines, auth backends, and policies. Feature flags
# control which components are enabled.
# -------------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terraform/modules/vault-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.vault_config_inputs
