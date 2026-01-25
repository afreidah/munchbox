# -------------------------------------------------------------------------------
# Nomad ACLs Module - Vault Secrets
#
# Project: Munchbox / Author: Alex Freidah
#
# Stores Nomad ACL tokens in Vault KV for secure retrieval by jobs. Services
# use Vault workload identity to access these secrets via templates.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# HASHI-UI SECRET
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "hashi_ui" {
  mount = var.vault_mount
  name  = "hashiuisecret"

  data_json = jsonencode({
    token = nomad_acl_token.hashi_ui.secret_id
  })
}

# -------------------------------------------------------------------------
# BACKUP WORKER SECRET
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "backup_worker" {
  mount = var.vault_mount
  name  = "backup-worker"

  data_json = jsonencode({
    nomad_token  = nomad_acl_token.backup_worker.secret_id
    consul_token = var.backup_consul_token
  })
}

# -------------------------------------------------------------------------
# PROMETHEUS SECRET
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "prometheus_nomad" {
  mount = var.vault_mount
  name  = "prometheus-nomad"

  data_json = jsonencode({
    nomad_token = nomad_acl_token.prometheus.secret_id
  })
}
