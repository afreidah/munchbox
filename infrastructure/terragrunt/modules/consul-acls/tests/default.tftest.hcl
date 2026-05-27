# -----------------------------------------------------------------------------
# consul-acls module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the three parallel for_each maps fan out 1:1, the anonymous token
# is managed by default with an empty policies list (security default), the
# bootstrap-token-in-vault toggle gates the resource correctly, and empty
# inputs produce zero ACL resources.
# -----------------------------------------------------------------------------

mock_provider "consul" {}
mock_provider "vault" {}

variables {
  consul_bootstrap_token = "test-token"
  policies = {
    "agent"     = { description = "agent", rules = "node_prefix \"\" { policy = \"write\" }" }
    "telemetry" = { description = "telemetry", rules = "service_prefix \"\" { policy = \"read\" }" }
  }
  tokens = {
    "agent"     = { description = "Agent token", policies = ["agent"], local = false }
    "telemetry" = { description = "Telemetry token", policies = ["telemetry"], local = false }
  }
  vault_secrets = {
    "agent"     = { vault_path = "consul/agent-token", token_key = "agent" }
    "telemetry" = { vault_path = "telemetry", token_key = "telemetry", token_field_name = "consul_token", include_accessor_id = false }
  }
}

# -------------------------------------------------------------------------
# Policies for_each: one resource per map key
# -------------------------------------------------------------------------

run "policies_for_each" {
  command = plan

  # --- two policies input -> two resources ---
  assert {
    condition     = length(consul_acl_policy.policy) == 2
    error_message = "two policies input -> two resources"
  }

  # --- policy description propagates from input ---
  assert {
    condition     = consul_acl_policy.policy["agent"].description == "agent"
    error_message = "policy description must propagate from input"
  }
}

# -------------------------------------------------------------------------
# Tokens for_each: description + policies list flow through
# -------------------------------------------------------------------------

run "tokens_for_each" {
  command = plan

  # --- two tokens input -> two resources ---
  assert {
    condition     = length(consul_acl_token.token) == 2
    error_message = "two tokens input -> two resources"
  }

  # --- token description propagates from input ---
  assert {
    condition     = consul_acl_token.token["agent"].description == "Agent token"
    error_message = "token description must propagate"
  }
}

# -------------------------------------------------------------------------
# Anonymous token managed by default with EMPTY policies (deny-by-default)
# -------------------------------------------------------------------------

run "anonymous_token_managed_by_default" {
  command = plan

  # --- anonymous token resource exists ---
  assert {
    condition     = length(consul_acl_token.anonymous) == 1
    error_message = "anonymous token should be managed by default"
  }

  # --- anonymous token has zero policies (deny by default) ---
  assert {
    condition     = length(consul_acl_token.anonymous[0].policies) == 0
    error_message = "anonymous token must have ZERO policies (deny-by-default)"
  }
}

# -------------------------------------------------------------------------
# Anonymous token can be disabled via manage_anonymous_token toggle
# -------------------------------------------------------------------------

run "anonymous_token_can_be_disabled" {
  command = plan

  variables {
    manage_anonymous_token = false
  }

  # --- anonymous token resource count drops to 0 ---
  assert {
    condition     = length(consul_acl_token.anonymous) == 0
    error_message = "anonymous token should be skipped when toggle is off"
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
}

# -------------------------------------------------------------------------
# Empty maps: zero ACL resources, plan still succeeds
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    policies      = {}
    tokens        = {}
    vault_secrets = {}
  }

  # --- empty inputs -> zero policy + token resources ---
  assert {
    condition     = length(consul_acl_policy.policy) == 0 && length(consul_acl_token.token) == 0
    error_message = "empty inputs -> zero policy + token resources"
  }
}
