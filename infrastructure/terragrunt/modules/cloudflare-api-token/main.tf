# -----------------------------------------------------------------------------
# CLOUDFLARE-API-TOKEN MODULE
# -----------------------------------------------------------------------------
#
# Mints scoped Cloudflare API tokens from a map of token requests. Permission
# groups are named by display name in the request and resolved to IDs via the
# permission-groups data source so callers never hardcode UUIDs. Token values
# are sensitive read-only outputs meant to be written straight to Vault.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PERMISSION GROUP NAME -> ID LOOKUP
# -----------------------------------------------------------------------------

data "cloudflare_api_token_permission_groups_list" "all" {}

locals {
  # --- group-by name tolerates duplicate names across scopes; take first ---
  pg_ids_by_name = {
    for pg in data.cloudflare_api_token_permission_groups_list.all.result :
    pg.name => pg.id...
  }
}

# -----------------------------------------------------------------------------
# API TOKENS
# -----------------------------------------------------------------------------

resource "cloudflare_api_token" "this" {
  for_each = var.tokens

  name       = each.value.name
  expires_on = each.value.expires_on

  policies = [
    for p in each.value.policies : {
      effect            = p.effect
      permission_groups = [for n in p.permission_groups : { id = local.pg_ids_by_name[n][0] }]
      resources         = jsonencode(p.resources)
    }
  ]
}
