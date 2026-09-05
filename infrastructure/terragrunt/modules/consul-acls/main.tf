# -----------------------------------------------------------------------------
# CONSUL-ACLS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Generic Consul ACL management module using for_each patterns. Creates ACL
# policies, tokens, and stores tokens securely in Vault KV. All specific
# policies and tokens are defined via input variables from root.hcl.
#
# Components:
#   - ACL Policies: Dynamic creation from policies map
#   - ACL Tokens: Dynamic creation bound to policies
#   - Vault Secrets: Secure token storage in Vault KV v2
#   - Anonymous Token: Managed with empty policies for security
#
# Architecture:
#   - Policies define permissions using Consul ACL rule syntax
#   - Tokens reference policies by name and are created after policies
#   - Token secrets stored in Vault, never exposed in Terraform outputs
#
# Security Model:
#   - Bootstrap token stored securely in Vault
#   - Anonymous token managed with no policies (default deny)
#   - Token IDs only accessible via Vault KV, not Terraform state
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# ACL POLICIES
# -------------------------------------------------------------------------

resource "consul_acl_policy" "policy" {
  for_each = var.policies

  name        = each.key
  description = each.value.description
  rules       = each.value.rules
}

# -------------------------------------------------------------------------
# ACL TOKENS
# -------------------------------------------------------------------------

resource "consul_acl_token" "token" {
  for_each = var.tokens

  description = each.value.description
  policies    = each.value.policies
  local       = each.value.local

  depends_on = [consul_acl_policy.policy]
}

# -------------------------------------------------------------------------
# TOKEN SECRETS
# -------------------------------------------------------------------------
# consul_acl_token exposes only the accessor as its id -- the provider keeps
# the secret off the resource deliberately. Consul rejects an accessor used
# as a token ("ACL not found"), so the value written to Vault has to come
# from here.

data "consul_acl_token_secret_id" "token" {
  for_each = var.tokens

  accessor_id = consul_acl_token.token[each.key].id
}

# -------------------------------------------------------------------------
# ANONYMOUS TOKEN
# -------------------------------------------------------------------------

resource "consul_acl_token" "anonymous" {
  count = var.manage_anonymous_token ? 1 : 0

  accessor_id = "00000000-0000-0000-0000-000000000002"
  description = "Anonymous Token - intentionally has no policies for security"
  policies    = []
  local       = false

  lifecycle {
    prevent_destroy = true
  }
}

# -------------------------------------------------------------------------
# VAULT SECRETS - BOOTSTRAP TOKEN
# -------------------------------------------------------------------------

resource "vault_kv_secret_v2" "bootstrap" {
  count = var.store_bootstrap_token ? 1 : 0
  mount = var.vault_mount
  name  = "consul/bootstrap-token"

  data_json = jsonencode({
    token       = var.consul_bootstrap_token
    description = "Consul ACL bootstrap token - CRITICAL"
  })
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
      (each.value.token_field_name) = data.consul_acl_token_secret_id.token[each.value.token_key].secret_id
    },
    each.value.include_accessor_id ? {
      accessor_id = consul_acl_token.token[each.value.token_key].accessor_id
    } : {}
  ))
}
