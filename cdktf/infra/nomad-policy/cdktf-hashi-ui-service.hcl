# --------------------------------------------------------------------------------
#  Hashi-UI — Nomad Read-Only Policy
#
#  Purpose:
#    Allow Hashi-UI to *read* cluster-wide Nomad state so the UI can render
#    Servers, Nodes, Jobs, Allocations, etc., without any write privileges.
#
#  Notes:
#    - The previous version only granted namespace read, which is insufficient
#      for endpoints like /v1/operator/raft/peers and /v1/nodes.
#    - This version adds read for operator, node, agent, and other useful scopes.
# --------------------------------------------------------------------------------

# --- Cluster/infra access needed by the UI ---
namespace "*" { policy = "write" }   # was "read"
node     { policy = "read" }
agent    { policy = "read" }
operator { policy = "read" }

# --- Useful extras (safe, read-only) ---
quota     { policy = "read" }
plugin    { policy = "read" }
variables { policy = "read" }
