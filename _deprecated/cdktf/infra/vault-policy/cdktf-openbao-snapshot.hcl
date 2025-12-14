# -------------------------------------------------------------------------------
# OpenBao Snapshot Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants read access to Raft snapshot endpoint for backup operations.
# -------------------------------------------------------------------------------

path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
