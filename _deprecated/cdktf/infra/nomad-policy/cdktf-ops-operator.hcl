# -------------------------------------------------------------------------------
# Ops Operator Policy - Nomad ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# SRE/operator day-to-day policy for draining nodes, exec into allocations, and
# reading logs without full admin access.
# -------------------------------------------------------------------------------
namespace "*" {
  policy       = "read"
  capabilities = ["alloc-exec", "alloc-lifecycle", "read-logs"]
}
node   { policy = "write" }
agent  { policy = "write" }
plugin { policy = "read" }
quota  { policy = "read" }

