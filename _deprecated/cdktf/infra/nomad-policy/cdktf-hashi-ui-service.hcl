# -------------------------------------------------------------------------------
# Hashi-UI Service Policy - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Hashi-UI read access to cluster state for rendering servers, nodes, jobs,
# and allocations in the web UI.
# -------------------------------------------------------------------------------

# --- Cluster/infra access needed by the UI ---
namespace "*" { policy = "write" }   # was "read"
node     { policy = "read" }
agent    { policy = "read" }
operator { policy = "read" }

# --- Useful extras (safe, read-only) ---
quota     { policy = "read" }
plugin    { policy = "read" }
variables { policy = "read" }
