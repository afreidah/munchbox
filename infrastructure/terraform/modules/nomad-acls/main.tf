# -----------------------------------------------------------------------------
# NOMAD-ACLS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Generic Nomad ACL management module using for_each patterns. Creates ACL
# policies, tokens, and stores tokens securely in Vault KV. All specific
# policies and tokens are defined via input variables from root.hcl.
#
# Components:
#   - ACL Policies: Dynamic creation from policies map (operators and services)
#   - ACL Tokens: Dynamic creation bound to policies
#   - Vault Secrets: Secure token storage in Vault KV v2
#
# Architecture:
#   - Policies define permissions using Nomad ACL rule HCL syntax
#   - Tokens reference policies by name and are created after policies
#   - Token secrets stored in Vault, never exposed in Terraform outputs
#   - Extra data (e.g., consul tokens) can be injected via extra_secret_values
#
# Security Model:
#   - Token secrets only accessible via Vault KV, not Terraform state
#   - Operator policies (admin, read-only) created but no tokens generated
#   - Service tokens stored securely for workload identity access
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# ACL POLICIES
# -------------------------------------------------------------------------

resource "nomad_acl_policy" "policy" {
  for_each = var.policies

  name        = each.key
  description = each.value.description
  rules_hcl   = each.value.rules_hcl
}

# -------------------------------------------------------------------------
# ACL TOKENS
# -------------------------------------------------------------------------

resource "nomad_acl_token" "token" {
  for_each = var.tokens

  name     = each.key
  type     = each.value.type
  policies = each.value.policies

  dynamic "expiration_ttl" {
    for_each = each.value.expiration != null ? [each.value.expiration] : []
    content {
      # Nomad ACL token expiration is set via expiration_time attribute
    }
  }

  depends_on = [nomad_acl_policy.policy]
}

# -------------------------------------------------------------------------
# VAULT SECRETS - TOKEN STORAGE
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "token" {
  for_each = var.vault_secrets

  mount = var.vault_mount
  name  = each.value.vault_path

  data_json = jsonencode(merge(
    {
      (each.value.token_field_name) = nomad_acl_token.token[each.value.token_key].secret_id
    },
    {
      for k, v in each.value.extra_data :
      k => lookup(var.extra_secret_values, v, v)
    }
  ))
}
