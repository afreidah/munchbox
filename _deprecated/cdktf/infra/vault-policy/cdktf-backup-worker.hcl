# -------------------------------------------------------------------------------
# Backup Worker Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants temporal-backup-worker read access to Nomad token for backup operations.
# -------------------------------------------------------------------------------

path "kv/data/backup-worker" {
  capabilities = ["read"]
}
