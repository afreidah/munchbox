# -------------------------------------------------------------------------------
# Anonymous DNS Policy - Consul ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Allows anonymous DNS queries to read node and service information from Consul.
# -------------------------------------------------------------------------------

node_prefix "" { policy = "read" }
service_prefix "" { policy = "read" }
