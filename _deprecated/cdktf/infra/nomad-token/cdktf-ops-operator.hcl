# -------------------------------------------------------------------------------
# Ops Operator Token - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# SRE/operator token for on-call duties and routine operations.
# -------------------------------------------------------------------------------
Name     = "ops-operator"
Type     = "client"
Policies = ["ops-operator", "system-deny"]

