# -------------------------------------------------------------------------------
# System Deny Policy - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Prevents non-admin users from accessing the system namespace for security.
# -------------------------------------------------------------------------------
namespace "system" { policy = "deny" }

