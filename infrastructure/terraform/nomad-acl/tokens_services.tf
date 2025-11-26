# -------------------------------------------------------------------------------
# Service Tokens
#
# Project: Munchbox / Author: Alex Freidah
#
# ACL tokens for automated services. Tokens are stored in Vault for secure
# retrieval by Nomad jobs via workload identity.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hashi-UI Token
# -----------------------------------------------------------------------------

resource "nomad_acl_token" "hashi_ui" {
  name     = "hashi-ui"
  type     = "client"
  policies = [nomad_acl_policy.hashi_ui.name]
}

# -----------------------------------------------------------------------------
# Backup Worker Token
# -----------------------------------------------------------------------------

resource "nomad_acl_token" "backup_worker" {
  name     = "backup-worker"
  type     = "client"
  policies = [nomad_acl_policy.backup_worker.name]
}

# -----------------------------------------------------------------------------
# Prometheus Token
# -----------------------------------------------------------------------------

resource "nomad_acl_token" "prometheus" {
  name     = "prometheus"
  type     = "client"
  policies = [nomad_acl_policy.prometheus.name]
}
