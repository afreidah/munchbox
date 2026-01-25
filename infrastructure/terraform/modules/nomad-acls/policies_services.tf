# -------------------------------------------------------------------------------
# Nomad ACLs Module - Service Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# ACL policies for automated services that need Nomad API access. Minimal
# privilege policies scoped to specific service requirements.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# HASHI-UI POLICY - DASHBOARD READ ACCESS
# -------------------------------------------------------------------------

resource "nomad_acl_policy" "hashi_ui" {
  name        = "hashi-ui"
  description = "Hashi-UI dashboard - read-only cluster visibility"

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
# BACKUP WORKER POLICY - SNAPSHOT ACCESS
# -------------------------------------------------------------------------

resource "nomad_acl_policy" "backup_worker" {
  name        = "backup-worker"
  description = "Temporal backup worker - snapshot and read access"

  rules_hcl = <<-EOT
    namespace "*" {
      policy = "read"
    }

    node {
      policy = "read"
    }

    agent {
      policy = "write"
    }

    operator {
      policy = "write"
    }
  EOT
}

# -------------------------------------------------------------------------
# PROMETHEUS POLICY - METRICS SCRAPING
# -------------------------------------------------------------------------

resource "nomad_acl_policy" "prometheus" {
  name        = "prometheus"
  description = "Prometheus metrics scraping access"

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
