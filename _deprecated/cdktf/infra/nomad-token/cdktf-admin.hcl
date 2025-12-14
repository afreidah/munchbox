# -------------------------------------------------------------------------------
# Admin Token - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Platform admin client token bound to admin policy for full cluster control.
# -------------------------------------------------------------------------------
Name     = "admin"
Type     = "client"
Policies = ["admin"]

