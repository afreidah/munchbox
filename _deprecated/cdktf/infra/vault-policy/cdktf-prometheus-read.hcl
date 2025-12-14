# -------------------------------------------------------------------------------
# Prometheus Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Prometheus read access to its configuration secrets in Vault.
# -------------------------------------------------------------------------------

path "kv/data/prometheus" {
  capabilities = ["read"]
}
