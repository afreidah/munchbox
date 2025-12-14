# -------------------------------------------------------------------------------
# Docker Registry Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants services read access to Docker registry authentication credentials.
# -------------------------------------------------------------------------------

path "kv/data/docker-registry" {
  capabilities = ["read"]
}
