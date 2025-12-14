# -------------------------------------------------------------------------------
# Ops Read Policy - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Read-only access to jobs, allocations, evaluations, and nodes for monitoring.
# -------------------------------------------------------------------------------

namespace "*" {
  policy = "read"
}

node {
  policy = "read"
}

agent {
  policy = "read"
}
