# -------------------------------------------------------------------------------
# GitHub Runner Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants GitHub Actions runners read access to runner registration token secrets.
# -------------------------------------------------------------------------------

path "kv/data/github/runner" {
  capabilities = ["read"]
}
