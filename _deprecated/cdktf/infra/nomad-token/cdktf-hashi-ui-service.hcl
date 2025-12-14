# -------------------------------------------------------------------------------
# Hashi-UI Service Token - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Client token for Hashi-UI with read access to nodes, agent, and namespaces.
# -------------------------------------------------------------------------------

Name     = "hashi-ui"
Type     = "client"
Policies = ["cdktf-hashi-ui-service"]

