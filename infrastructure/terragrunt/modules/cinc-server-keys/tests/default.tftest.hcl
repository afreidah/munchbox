# -----------------------------------------------------------------------------
# cinc-server-keys module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the generation config and the vault_data shape; generated values are
# known-after-apply under mocks.
# -----------------------------------------------------------------------------

mock_provider "random" {}
mock_provider "tls" {}

variables {
  users = {
    "forgejo-ci" = {}
  }
}

# -------------------------------------------------------------------------
# defaults: 32-char alphanumeric password + 2048-bit RSA keypair
# -------------------------------------------------------------------------

run "generates_password_and_keypair" {
  command = plan

  # --- 32 characters ---
  assert {
    condition     = random_password.user["forgejo-ci"].length == 32
    error_message = "user password should default to 32 characters"
  }

  # --- no special characters (password is an argv element to chef-server-ctl) ---
  assert {
    condition     = random_password.user["forgejo-ci"].special == false
    error_message = "user password should be alphanumeric (special disabled)"
  }

  # --- RSA is the only algorithm the Chef Server API signs with ---
  assert {
    condition     = tls_private_key.user["forgejo-ci"].algorithm == "RSA"
    error_message = "user key must be RSA"
  }

  # --- matches the server's own keygen size ---
  assert {
    condition     = tls_private_key.user["forgejo-ci"].rsa_bits == 2048
    error_message = "user key should default to 2048 bits"
  }

  # --- vault_data is keyed by username ---
  assert {
    condition     = toset(keys(nonsensitive(output.vault_data))) == toset(["forgejo-ci"])
    error_message = "vault_data must be keyed by username"
  }

  # --- each user carries the password plus both halves of the keypair ---
  assert {
    condition     = toset(keys(nonsensitive(output.vault_data)["forgejo-ci"])) == toset(["password", "private_key", "public_key"])
    error_message = "vault_data entry must expose password, private_key and public_key"
  }
}

# -------------------------------------------------------------------------
# per-user overrides win over the defaults
# -------------------------------------------------------------------------

run "honours_per_user_overrides" {
  command = plan

  variables {
    users = {
      "forgejo-ci" = { password_length = 48, rsa_bits = 4096 }
    }
  }

  assert {
    condition     = random_password.user["forgejo-ci"].length == 48
    error_message = "password_length override should be applied"
  }

  assert {
    condition     = tls_private_key.user["forgejo-ci"].rsa_bits == 4096
    error_message = "rsa_bits override should be applied"
  }
}

# -------------------------------------------------------------------------
# no users -> no resources, empty vault_data
# -------------------------------------------------------------------------

run "empty_users_generates_nothing" {
  command = plan

  variables {
    users = {}
  }

  assert {
    condition     = length(nonsensitive(output.vault_data)) == 0
    error_message = "vault_data must be empty when no users are requested"
  }
}
