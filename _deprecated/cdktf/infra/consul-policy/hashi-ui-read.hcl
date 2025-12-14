# -------------------------------------------------------------------------------
# Hashi-UI Read Policy - Consul ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Hashi-UI read access to Consul catalog, health, and KV for UI rendering.
# -------------------------------------------------------------------------------

# Single-agent read stanza (consistent with your style in other policies)
agent {
  policy = "read"
}

# Catalog/health read across the board
agent_prefix   "" { policy = "read" }
node_prefix    "" { policy = "read" }
service_prefix "" { policy = "read" }
query_prefix   "" { policy = "read" }

# enable KV browsing from UI
key_prefix "" { policy = "read" }

