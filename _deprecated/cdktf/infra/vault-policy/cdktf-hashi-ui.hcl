# -------------------------------------------------------------------------------
# Hashi-UI Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Hashi-UI read access to Nomad token secret for cluster management UI.
# -------------------------------------------------------------------------------

path "secret/data/hashiuisecret" {
  capabilities = ["read"]
}
