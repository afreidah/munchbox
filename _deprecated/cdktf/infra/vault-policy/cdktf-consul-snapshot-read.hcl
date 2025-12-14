# -------------------------------------------------------------------------------
# Consul Snapshot Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Consul snapshot service read access to its credentials in Vault.
# -------------------------------------------------------------------------------

path "kv/data/consul-snapshot" {
  capabilities = ["read"]
}
