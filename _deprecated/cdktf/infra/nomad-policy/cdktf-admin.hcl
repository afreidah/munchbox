# -------------------------------------------------------------------------------
# Admin Policy - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Full admin control via client token for day-to-day operations without needing
# management tokens. Grants write access to all namespaces, nodes, and plugins.
# -------------------------------------------------------------------------------
namespace "*" { policy = "write" }      # submit/scale/exec/logs/etc.
node         { policy = "write" }       # drain/cordon
agent        { policy = "write" }       # agent maintenance
operator     { policy = "write" }       # cluster ops
quota        { policy = "write" }
plugin       { policy = "write" }
host_volume "*" { policy = "write" }    # if you use host volumes
