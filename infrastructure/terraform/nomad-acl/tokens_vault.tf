# -------------------------------------------------------------------------------
# Vault Secrets
#
# Project: Munchbox / Author: Alex Freidah
#
# Stores Nomad ACL tokens in Vault for secure retrieval by jobs. Jobs use
# Vault workload identity to access these secrets via templates.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hashi-UI Secret
#
# Path: secret/data/hashiuisecret
# Used by: hashi-ui job template (nomad.env.tpl)
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "hashi_ui" {
  mount = "secret"
  name  = "hashiuisecret"

  data_json = jsonencode({
    token = nomad_acl_token.hashi_ui.secret_id
  })
}

# -----------------------------------------------------------------------------
# Backup Worker Secret
#
# Path: kv/data/backup-worker
# Used by: temporal-backup-worker job template (tokens.env.tpl)
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "backup_worker" {
  mount = "secret"
  name  = "backup-worker"

  data_json = jsonencode({
    nomad_token  = nomad_acl_token.backup_worker.secret_id
    consul_token = var.backup_consul_token
  })
}

# -----------------------------------------------------------------------------
# Prometheus Secret
#
# Path: kv/data/prometheus
# Used by: prometheus job for Nomad metrics scraping
# Note: Also contains consul_token managed separately
# -----------------------------------------------------------------------------

# Prometheus already has kv/data/prometheus with consul_token
# We need to update it to include the nomad_token
# This is handled via a separate data source + merge if needed

resource "vault_kv_secret_v2" "prometheus_nomad" {
  mount = "secret"
  name  = "prometheus-nomad"

  data_json = jsonencode({
    nomad_token = nomad_acl_token.prometheus.secret_id
  })
}
