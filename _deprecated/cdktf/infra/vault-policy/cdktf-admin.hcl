# -------------------------------------------------------------------------------
# Admin Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Full admin access to all Vault paths including sudo capabilities.
# -------------------------------------------------------------------------------

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
