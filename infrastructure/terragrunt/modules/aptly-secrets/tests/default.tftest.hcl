# -----------------------------------------------------------------------------
# aptly-secrets module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the password generation config; hashed values are known-after-apply
# under mocks.
# -----------------------------------------------------------------------------

mock_provider "random" {}
mock_provider "htpasswd" {}

variables {
  username = "admin"
}

# -------------------------------------------------------------------------
# password is a 32-char alphanumeric secret
# -------------------------------------------------------------------------

run "generates_alphanumeric_password" {
  command = plan

  # --- 32 characters ---
  assert {
    condition     = random_password.admin.length == 32
    error_message = "admin password should be 32 characters"
  }

  # --- no special characters (avoids basic-auth / URL edge cases) ---
  assert {
    condition     = random_password.admin.special == false
    error_message = "admin password should be alphanumeric (special disabled)"
  }
}
