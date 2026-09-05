# -----------------------------------------------------------------------------
# GOSSIP KEYS ENV HELPER
# -----------------------------------------------------------------------------
#
# Generates the Serf gossip keys. Vault-free: the values are written to Vault
# by the vault-secrets leaf via dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//gossip-keys"
}

inputs = {
  keys = {
    nomad = {}
  }
}
