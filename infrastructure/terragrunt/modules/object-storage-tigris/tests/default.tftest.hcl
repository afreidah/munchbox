# -----------------------------------------------------------------------------
# object-storage-tigris module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: bucket_name flows into the single
# tigris_bucket resource, with no location block (global bucket).
# -----------------------------------------------------------------------------

mock_provider "tigris" {}

variables {
  bucket_name = "munchbox-test-bucket"
}

# -------------------------------------------------------------------------
# Input flows through to the single bucket resource
# -------------------------------------------------------------------------

run "input_flows_through" {
  command = plan

  # --- bucket_name passes through to resource.bucket ---
  assert {
    condition     = tigris_bucket.this.bucket == var.bucket_name
    error_message = "bucket must match var.bucket_name"
  }

  # --- output: bucket mirrors the input ---
  assert {
    condition     = output.bucket == var.bucket_name
    error_message = "bucket output must match var.bucket_name"
  }
}
