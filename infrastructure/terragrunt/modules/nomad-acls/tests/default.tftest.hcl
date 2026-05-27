# -----------------------------------------------------------------------------
# nomad-acls module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the three parallel for_each maps fan out 1:1 (policies / tokens /
# vault_secrets), management tokens get an empty policies list (per the
# conditional in main.tf), and the minimal empty-input config produces zero
# resources.
# -----------------------------------------------------------------------------

mock_provider "nomad" {}
mock_provider "vault" {}

variables {
  nomad_bootstrap_token = "test-token"
  policies = {
    "admin"      = { description = "admin", rules_hcl = "namespace \"*\" { policy = \"write\" }" }
    "prometheus" = { description = "prometheus", rules_hcl = "namespace \"*\" { policy = \"read\" }" }
  }
  tokens = {
    "admin"      = { type = "management", policies = [] }
    "prometheus" = { policies = ["prometheus"] }
  }
  vault_secrets = {
    "admin"      = { vault_path = "admin", token_key = "admin", token_field_name = "nomad_token" }
    "prometheus" = { vault_path = "prom", token_key = "prometheus", token_field_name = "nomad_token" }
  }
}

# -------------------------------------------------------------------------
# Policies for_each: one resource per map key
# -------------------------------------------------------------------------

run "policies_for_each" {
  command = plan

  # --- two policies input -> two resources ---
  assert {
    condition     = length(nomad_acl_policy.policy) == 2
    error_message = "two policies input -> two resources"
  }

  # --- description propagates from input map ---
  assert {
    condition     = nomad_acl_policy.policy["admin"].description == "admin"
    error_message = "admin policy description must propagate"
  }
}

# -------------------------------------------------------------------------
# Management token forces empty policies list (per conditional in main.tf)
# -------------------------------------------------------------------------

run "management_token_empty_policies" {
  command = plan

  # --- two tokens input -> two token resources ---
  assert {
    condition     = length(nomad_acl_token.token) == 2
    error_message = "two tokens input -> two resources"
  }

  # --- management type forces empty policies list ---
  assert {
    condition     = length(nomad_acl_token.token["admin"].policies) == 0
    error_message = "management token must have empty policies list (per conditional)"
  }

  # --- non-management token keeps its policies ---
  assert {
    condition     = length(nomad_acl_token.token["prometheus"].policies) == 1
    error_message = "non-management token keeps its policies"
  }
}

# -------------------------------------------------------------------------
# vault_secrets for_each: one KV resource per map key
# -------------------------------------------------------------------------

run "vault_secrets_for_each" {
  command = plan

  # --- two vault_secrets entries -> two KV resources ---
  assert {
    condition     = length(vault_kv_secret_v2.token) == 2
    error_message = "two vault_secrets entries -> two KV resources"
  }

  # --- vault KV name comes from vault_path input ---
  assert {
    condition     = vault_kv_secret_v2.token["admin"].name == "admin"
    error_message = "vault KV name should be vault_path from input"
  }
}

# -------------------------------------------------------------------------
# Empty maps: zero resources, plan still succeeds
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    policies      = {}
    tokens        = {}
    vault_secrets = {}
  }

  # --- no policies created from empty map ---
  assert {
    condition     = length(nomad_acl_policy.policy) == 0
    error_message = "empty policies -> zero policy resources"
  }

  # --- no tokens created from empty map ---
  assert {
    condition     = length(nomad_acl_token.token) == 0
    error_message = "empty tokens -> zero token resources"
  }
}
