# -------------------------------------------------------------------------------
# Ops Read Token - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Read-only token for dashboards, auditors, and monitoring systems.
# -------------------------------------------------------------------------------
Name     = "ops-read"
Type     = "client"
Policies = ["ops-read", "system-deny"]
