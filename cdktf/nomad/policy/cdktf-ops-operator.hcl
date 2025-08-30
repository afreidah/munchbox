# -------------------------------------------------------------------------------
# cdktf-ops-operator.hcl
# SRE/operator day-to-day: drain nodes, exec into allocs, read logs
# -------------------------------------------------------------------------------
namespace "*" {
  policy       = "read"
  capabilities = ["alloc-exec", "alloc-lifecycle", "read-logs"]
}
node   { policy = "write" }
agent  { policy = "write" }
plugin { policy = "read" }
quota  { policy = "read" }

