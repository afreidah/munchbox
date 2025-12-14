# -------------------------------------------------------------------------------
# Operator Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Read-only operator access to secrets and policies without write capabilities.
# -------------------------------------------------------------------------------

path "secret/data/*" {
  capabilities = ["read", "list"]
}

# Allow reading policies (optional)
path "sys/policies/acl" {
  capabilities = ["read", "list"]
}
