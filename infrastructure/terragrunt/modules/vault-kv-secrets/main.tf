# -----------------------------------------------------------------------------
# VAULT-KV-SECRETS MODULE
# -----------------------------------------------------------------------------
#
# Writes a map of externally-supplied secrets to Vault KV v2, one resource per
# entry. Generic: it knows nothing about the sources, so one consumer leaf can
# feed it many dependency outputs. Iterates over keys() so for_each is driven
# by the non-sensitive names even when the data values are sensitive.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "this" {
  for_each = toset(keys(var.secrets))

  mount     = var.secrets[each.key].mount
  name      = each.key
  data_json = jsonencode(var.secrets[each.key].data)
}
