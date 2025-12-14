# -------------------------------------------------------------------------------
# Traefik Catalog Read Policy - Consul ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Traefik read access to Consul catalog for service discovery and routing.
# -------------------------------------------------------------------------------

agent_prefix  ""  { policy = "read" }
node_prefix   ""  { policy = "read" }
service_prefix "" { policy = "read" }
query_prefix  ""  { policy = "read" }
