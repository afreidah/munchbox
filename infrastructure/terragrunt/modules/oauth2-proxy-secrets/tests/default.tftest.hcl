# -----------------------------------------------------------------------------
# oauth2-proxy-secrets module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the conditional cookie_secret behavior: random_bytes resource is
# created only when var.cookie_secret is null or empty, and the vault KV
# item lands at the expected mount/name with the right data shape.
# -----------------------------------------------------------------------------

mock_provider "vault" {}
mock_provider "random" {}

variables {
  client_id      = "test-client-id"
  client_secret  = "test-client-secret"
  allowed_emails = ["alice@example.com", "bob@example.com"]
}

# -------------------------------------------------------------------------
# cookie_secret null -> module generates a random one
# -------------------------------------------------------------------------

run "generates_cookie_secret_when_null" {
  command = plan

  # --- random_bytes resource is created (count = 1) ---
  assert {
    condition     = length(random_bytes.cookie_secret) == 1
    error_message = "random_bytes should be generated when cookie_secret is null"
  }
}

# -------------------------------------------------------------------------
# Explicit cookie_secret -> no random_bytes generation
# -------------------------------------------------------------------------

run "skips_generation_when_cookie_provided" {
  command = plan

  variables {
    cookie_secret = "pre-existing-secret"
  }

  # --- random_bytes count = 0 when caller supplies the secret ---
  assert {
    condition     = length(random_bytes.cookie_secret) == 0
    error_message = "random_bytes should be skipped when cookie_secret is provided"
  }
}

# -------------------------------------------------------------------------
# Empty-string cookie_secret also triggers generation
# -------------------------------------------------------------------------

run "generates_when_empty_string" {
  command = plan

  variables {
    cookie_secret = ""
  }

  # --- empty string == null behavior; resource is created ---
  assert {
    condition     = length(random_bytes.cookie_secret) == 1
    error_message = "random_bytes should be generated when cookie_secret is empty string"
  }
}

# -------------------------------------------------------------------------
# Vault KV item lands at the expected mount + name
# -------------------------------------------------------------------------

run "vault_kv_target" {
  command = plan

  # --- mount comes from var.vault_mount default ("secret") ---
  assert {
    condition     = vault_kv_secret_v2.oauth2_proxy.mount == var.vault_mount
    error_message = "vault KV mount must match var.vault_mount"
  }

  # --- name is the hardcoded "oauth2-proxy" string ---
  assert {
    condition     = vault_kv_secret_v2.oauth2_proxy.name == "oauth2-proxy"
    error_message = "vault KV name must be 'oauth2-proxy'"
  }
}

# -------------------------------------------------------------------------
# Custom vault_mount flows through
# -------------------------------------------------------------------------

run "custom_vault_mount" {
  command = plan

  variables {
    vault_mount = "custom-secrets"
  }

  # --- override mount propagates to the KV resource ---
  assert {
    condition     = vault_kv_secret_v2.oauth2_proxy.mount == "custom-secrets"
    error_message = "custom vault_mount should flow through"
  }
}
