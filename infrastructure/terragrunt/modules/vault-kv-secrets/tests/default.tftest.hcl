# -----------------------------------------------------------------------------
# vault-kv-secrets module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the secrets map fans out one KV v2 resource per entry, keyed by name.
# -----------------------------------------------------------------------------

mock_provider "vault" {}

variables {
  secrets = {
    "cloudflare-wandns" = { data = { api_token = "mock-token", zone_id = "z1" } }
    "aptly-admin"       = { data = { password = "mock-pass", htpasswd = "admin:mock" } }
  }
}

# -------------------------------------------------------------------------
# each map entry renders one KV secret at its name
# -------------------------------------------------------------------------

run "fans_out_per_entry" {
  command = plan

  # --- two entries -> two KV resources ---
  assert {
    condition     = length(vault_kv_secret_v2.this) == 2
    error_message = "two secrets entries -> two vault_kv_secret_v2 resources"
  }

  # --- each secret is named by its map key ---
  assert {
    condition     = vault_kv_secret_v2.this["aptly-admin"].name == "aptly-admin"
    error_message = "each secret should be named by its map key"
  }
}
