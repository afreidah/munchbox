# -----------------------------------------------------------------------------
# gossip-keys module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the key fan-out and byte length; the base64 value itself is
# known-after-apply under mocks.
# -----------------------------------------------------------------------------

mock_provider "random" {}

# -------------------------------------------------------------------------
# One key per map entry, defaulting to the 32 bytes Serf expects
# -------------------------------------------------------------------------

run "generates_a_key_per_entry" {
  command = plan

  variables {
    keys = {
      nomad  = {}
      consul = { byte_length = 32 }
    }
  }

  # --- both entries fan out ---
  assert {
    condition     = length(random_bytes.key) == 2
    error_message = "each keys entry should generate one random_bytes resource"
  }

  # --- byte_length defaults to 32 when omitted ---
  assert {
    condition     = random_bytes.key["nomad"].length == 32
    error_message = "byte_length should default to 32"
  }

  # --- vault_data is keyed by the map key a consumer reads ---
  assert {
    condition     = toset(keys(nonsensitive(output.vault_data))) == toset(["nomad", "consul"])
    error_message = "vault_data must be keyed by the keys map"
  }
}

# -------------------------------------------------------------------------
# An explicit byte_length overrides the default
# -------------------------------------------------------------------------

run "honours_explicit_byte_length" {
  command = plan

  variables {
    keys = {
      wide = { byte_length = 64 }
    }
  }

  assert {
    condition     = random_bytes.key["wide"].length == 64
    error_message = "explicit byte_length should be used"
  }
}

# -------------------------------------------------------------------------
# No keys declared -> nothing generated
# -------------------------------------------------------------------------

run "empty_by_default" {
  command = plan

  assert {
    condition     = length(random_bytes.key) == 0
    error_message = "no keys should be generated when the map is empty"
  }
}
