# -----------------------------------------------------------------------------
# forgejo-secrets module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the for_each composition: the secrets map fans out into one
# forgejo_repository_action_secret per key, secret_name flows through, and
# the empty-map edge case produces zero resources.
# -----------------------------------------------------------------------------

mock_provider "forgejo" {
  mock_data "forgejo_repository" {
    defaults = { id = 42 }
  }
}

mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = { token = "mock-token-value", password = "mock-password" }
    }
  }
}

variables {
  repository_owner = "alex"
  repository_name  = "munchbox"
  secrets = {
    "token-a" = { vault_path = "service-a", vault_field = "token", secret_name = "SERVICE_A_TOKEN" }
    "token-b" = { vault_path = "service-b", vault_field = "token", secret_name = "SERVICE_B_TOKEN" }
  }
}

# -------------------------------------------------------------------------
# secrets map fans out 1:1 via for_each
# -------------------------------------------------------------------------

run "for_each_fans_out" {
  command = plan

  # --- one secret resource per input map entry ---
  assert {
    condition     = length(forgejo_repository_action_secret.secrets) == 2
    error_message = "for_each must create one resource per secrets-map entry"
  }

  # --- input map key 'token-a' becomes a resource address key ---
  assert {
    condition     = contains(keys(forgejo_repository_action_secret.secrets), "token-a")
    error_message = "secret 'token-a' must exist in the for_each map"
  }
}

# -------------------------------------------------------------------------
# secret_name from input flows to the resource name attribute
# -------------------------------------------------------------------------

run "secret_name_propagates" {
  command = plan

  # --- token-a maps to SERVICE_A_TOKEN ---
  assert {
    condition     = forgejo_repository_action_secret.secrets["token-a"].name == "SERVICE_A_TOKEN"
    error_message = "secret name must come from secrets[key].secret_name"
  }

  # --- token-b maps to SERVICE_B_TOKEN ---
  assert {
    condition     = forgejo_repository_action_secret.secrets["token-b"].name == "SERVICE_B_TOKEN"
    error_message = "secret name must come from secrets[key].secret_name"
  }
}

# -------------------------------------------------------------------------
# Empty secrets map: zero resources, no errors
# -------------------------------------------------------------------------

run "empty_secrets_map" {
  command = plan

  variables {
    secrets = {}
  }

  # --- empty input produces zero resources ---
  assert {
    condition     = length(forgejo_repository_action_secret.secrets) == 0
    error_message = "empty secrets map should produce zero resources"
  }
}
