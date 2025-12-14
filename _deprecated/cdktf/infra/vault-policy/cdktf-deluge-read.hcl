# -------------------------------------------------------------------------------
# Deluge Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Deluge BitTorrent client read access to authentication credentials.
# -------------------------------------------------------------------------------

path "kv/data/deluge" {
  capabilities = ["read"]
}
