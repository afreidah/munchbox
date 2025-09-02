# cdktf-ops-read.hcl
# Nomad policy granting read-only access to jobs, allocations, evaluations, and nodes.

namespace "*" {
  policy = "read"
}

node {
  policy = "read"
}

agent {
  policy = "read"
}
