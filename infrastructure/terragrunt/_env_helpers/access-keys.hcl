# -----------------------------------------------------------------------------
# ACCESS-KEYS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates access-key / secret-key credential pairs from root.hcl's
# access_key_requests map. Vault-free: the pairs are exposed as outputs and
# written to Vault by the vault-secrets leaf via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//access-keys"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  credentials = local.root.locals.access_key_requests
}
