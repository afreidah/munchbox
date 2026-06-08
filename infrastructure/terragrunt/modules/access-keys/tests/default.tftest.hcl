# -----------------------------------------------------------------------------
# access-keys module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the per-entry fan-out (one id + one secret resource per credential)
# and the empty-map edge case. The generated values are unknown at plan, so
# the assertions check resource counts, not the secret strings.
# -----------------------------------------------------------------------------

variables {
  credentials = {
    "s3-bucket/unified" = {}
    "s3-bucket/aptly"   = { secret_length = 48 }
  }
}

# -------------------------------------------------------------------------
# one id + one secret resource per credential entry
# -------------------------------------------------------------------------

run "fan_out" {
  command = plan

  # --- two entries -> two access-key strings ---
  assert {
    condition     = length(random_string.access_key) == 2
    error_message = "two credentials -> two access-key resources"
  }

  # --- two entries -> two secret-key resources ---
  assert {
    condition     = length(random_password.secret_key) == 2
    error_message = "two credentials -> two secret-key resources"
  }

  # --- per-entry secret_length override is honored ---
  assert {
    condition     = random_password.secret_key["s3-bucket/aptly"].length == 48
    error_message = "explicit secret_length should be respected"
  }

  # --- default id length is the S3-style 20 ---
  assert {
    condition     = random_string.access_key["s3-bucket/unified"].length == 20
    error_message = "id_length should default to 20"
  }
}

# -------------------------------------------------------------------------
# empty map -> no resources
# -------------------------------------------------------------------------

run "empty" {
  command = plan

  variables {
    credentials = {}
  }

  # --- empty credentials -> zero resources ---
  assert {
    condition     = length(random_string.access_key) == 0
    error_message = "empty credentials -> zero access-key resources"
  }
}
