# -----------------------------------------------------------------------------
# passwords module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the generation config and the vault_data shape; generated values are
# known-after-apply under mocks.
# -----------------------------------------------------------------------------

mock_provider "random" {}

variables {
  passwords = {
    "proxmox/api-token" = {
      id     = { length = 24 }
      secret = { length = 36 }
    }
  }
}

# -------------------------------------------------------------------------
# one resource per field, addressed as <name>/<field>
# -------------------------------------------------------------------------

run "generates_one_password_per_field" {
  command = plan

  # --- the flattened for_each key is what `terraform import` addresses ---
  assert {
    condition     = random_password.this["proxmox/api-token/id"].length == 24
    error_message = "per-field length should be applied"
  }

  assert {
    condition     = random_password.this["proxmox/api-token/secret"].length == 36
    error_message = "per-field length should be applied"
  }

  # --- vault_data is keyed by secret name, then field ---
  assert {
    condition     = toset(keys(nonsensitive(output.vault_data))) == toset(["proxmox/api-token"])
    error_message = "vault_data must be keyed by secret name"
  }

  assert {
    condition     = toset(keys(nonsensitive(output.vault_data)["proxmox/api-token"])) == toset(["id", "secret"])
    error_message = "vault_data entry must expose one key per field"
  }
}

# -------------------------------------------------------------------------
# defaults apply when a field sets no options
# -------------------------------------------------------------------------

run "defaults_to_32_chars_with_specials" {
  command = plan

  variables {
    passwords = {
      "vaultwarden/master-password" = { password = {} }
    }
  }

  assert {
    condition     = random_password.this["vaultwarden/master-password/password"].length == 32
    error_message = "length should default to 32"
  }

  assert {
    condition     = random_password.this["vaultwarden/master-password/password"].special == true
    error_message = "special should default to true"
  }
}

# -------------------------------------------------------------------------
# no entries -> no resources, empty vault_data
# -------------------------------------------------------------------------

run "empty_passwords_generates_nothing" {
  command = plan

  variables {
    passwords = {}
  }

  assert {
    condition     = length(nonsensitive(output.vault_data)) == 0
    error_message = "vault_data must be empty when nothing is requested"
  }
}
