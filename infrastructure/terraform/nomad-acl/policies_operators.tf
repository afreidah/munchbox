# -------------------------------------------------------------------------------
# Operator Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# ACL policies for human operators. Defines admin (full access) and read-only
# (monitoring/viewing) access levels.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Admin Policy - Full Cluster Access
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "admin" {
  name        = "admin"
  description = "Full cluster administration access"

  rules_hcl = <<-EOT
    # Full namespace access with exec capabilities
    namespace "*" {
      policy       = "write"
      capabilities = ["alloc-exec", "alloc-node-exec", "alloc-lifecycle"]
    }

    # Node management
    node {
      policy = "write"
    }

    # Agent operations
    agent {
      policy = "write"
    }

    # Operator commands (raft, scheduler config)
    operator {
      policy = "write"
    }

    # Plugin management
    plugin {
      policy = "read"
    }

    # Host volume access
    host_volume "*" {
      policy = "write"
    }
  EOT
}

# -----------------------------------------------------------------------------
# Read-Only Policy - Monitoring Access
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "read_only" {
  name        = "read-only"
  description = "Read-only cluster monitoring access"

  rules_hcl = <<-EOT
    namespace "*" {
      policy = "read"
    }

    node {
      policy = "read"
    }

    agent {
      policy = "read"
    }
  EOT
}

# -----------------------------------------------------------------------------
# Developer Policy - Job Management
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "developer" {
  name        = "developer"
  description = "Job management in default namespace"

  rules_hcl = <<-EOT
    namespace "default" {
      policy       = "write"
      capabilities = ["alloc-exec", "alloc-lifecycle"]
    }

    node {
      policy = "read"
    }

    agent {
      policy = "read"
    }

    host_volume "*" {
      policy = "read"
    }
  EOT
}
