# -------------------------------------------------------------------------------
# SERVICE TOKENS
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates long-lived tokens for services/automation with specified policies.
# Tokens are stored in KV for syncing to external systems (e.g., Forgejo).
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# SERVICE TOKENS
# -------------------------------------------------------------------------

resource "vault_token" "service" {
  for_each = var.service_tokens

  display_name = each.key
  policies     = each.value.policies
  ttl          = lookup(each.value, "ttl", "8760h")
  renewable    = lookup(each.value, "renewable", true)
  no_parent    = true
}

# -------------------------------------------------------------------------
# STORE TOKENS IN KV
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "service_token" {
  for_each = var.kv_enabled ? var.service_tokens : {}

  mount = var.kv_path
  name  = each.value.vault_path

  data_json = jsonencode(merge(
    { token = vault_token.service[each.key].client_token },
    lookup(each.value, "extra_data", {})
  ))

  depends_on = [vault_mount.kv]
}
