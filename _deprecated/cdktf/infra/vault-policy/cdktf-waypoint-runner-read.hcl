# -------------------------------------------------------------------------------
# Waypoint Runner Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Allows Waypoint runner and bootstrap tasks to read/write the server token.
# -------------------------------------------------------------------------------

path "secret/data/system-services/waypoint_server_token" {
  capabilities = ["create", "read", "update"]
}
