# -----------------------------------------------------------------------------
# cloudflare-r2 module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: account_id + bucket_name flow into
# the single cloudflare_r2_bucket resource, and the WNAM location is pinned.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  account_id  = "02e53aa2113dc76e57f9598af2f74939"
  bucket_name = "munchbox-test-bucket"
}

# -------------------------------------------------------------------------
# Inputs flow through to the single bucket resource
# -------------------------------------------------------------------------

run "inputs_flow_through" {
  command = plan

  # --- bucket_name passes through to resource.name ---
  assert {
    condition     = cloudflare_r2_bucket.bucket.name == var.bucket_name
    error_message = "bucket name must match var.bucket_name"
  }

  # --- account_id passes through to resource.account_id ---
  assert {
    condition     = cloudflare_r2_bucket.bucket.account_id == var.account_id
    error_message = "bucket account_id must match var.account_id"
  }
}

# -------------------------------------------------------------------------
# Bucket region pinned to WNAM (no var, no override)
# -------------------------------------------------------------------------

run "location_pinned_wnam" {
  command = plan

  # --- location is a literal constant in the module ---
  assert {
    condition     = cloudflare_r2_bucket.bucket.location == "WNAM"
    error_message = "bucket location must be WNAM (hardcoded)"
  }
}
