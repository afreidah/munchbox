# -------------------------------------------------------------------------------
# Nomad ACLs Module - Operator Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# ACL policies for human operators. Defines admin (full access), read-only
# (monitoring), and developer (job management) access levels.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# ADMIN POLICY - FULL CLUSTER ACCESS
# -------------------------------------------------------------------------

resource "nomad_acl_policy" "admin" {
  name        = "admin"
  description = "Full cluster administration access"

  rules_hcl = <<-EOT
    namespace "*" {
      policy       = "write"
      capabilities = ["alloc-exec", "alloc-node-exec", "alloc-lifecycle"]
    }

    node {
      policy = "write"
    }

    agent {
      policy = "write"
    }

    operator {
      policy = "write"
    }

    plugin {
      policy = "read"
    }

    host_volume "*" {
      policy = "write"
    }
  EOT
}

# -------------------------------------------------------------------------
# READ-ONLY POLICY - MONITORING ACCESS
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# DEVELOPER POLICY - JOB MANAGEMENT
# -------------------------------------------------------------------------

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
