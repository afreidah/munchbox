# -------------------------------------------------------------------------------
# Service Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# ACL policies for automated services that need Nomad API access. These are
# minimal-privilege policies for specific service requirements.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hashi-UI Policy - Dashboard Read Access
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "hashi_ui" {
  name        = "hashi-ui"
  description = "Hashi-UI dashboard - read-only cluster visibility"

  rules_hcl = <<-EOT
    # Read all namespaces for job/alloc visibility
    namespace "*" {
      policy = "read"
    }

    # Node info for cluster overview
    node {
      policy = "read"
    }

    # Agent info for server status
    agent {
      policy = "read"
    }
  EOT
}

# -----------------------------------------------------------------------------
# Backup Worker Policy - Snapshot Access
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "backup_worker" {
  name        = "backup-worker"
  description = "Temporal backup worker - snapshot and read access"

  rules_hcl = <<-EOT
    # Read job/allocation state for backup metadata
    namespace "*" {
      policy = "read"
    }

    # Read node info
    node {
      policy = "read"
    }

    # Agent info for leader detection
    agent {
      policy = "read"
    }

    # Operator read for snapshot operations
    operator {
      policy = "read"
    }
  EOT
}

# -----------------------------------------------------------------------------
# Prometheus Policy - Metrics Scraping
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "prometheus" {
  name        = "prometheus"
  description = "Prometheus metrics scraping access"

  rules_hcl = <<-EOT
    # Read namespace metrics
    namespace "*" {
      policy = "read"
    }

    # Node metrics
    node {
      policy = "read"
    }

    # Agent metrics endpoint
    agent {
      policy = "read"
    }
  EOT
}

# -----------------------------------------------------------------------------
# Woodpecker Policy - CI/CD Job Deployment
# -----------------------------------------------------------------------------

resource "nomad_acl_policy" "woodpecker" {
  name        = "woodpecker"
  description = "Woodpecker CI/CD - job deployment and monitoring"

  rules_hcl = <<-EOT
    # Write access for job submission and management
    namespace "default" {
      policy       = "write"
      capabilities = ["alloc-exec", "alloc-lifecycle", "read-logs"]
    }

    # Read node info for placement visibility
    node {
      policy = "read"
    }

    # Read agent info for cluster status
    agent {
      policy = "read"
    }

    # Read host volumes for job specs
    host_volume "*" {
      policy = "read"
    }
  EOT
}
