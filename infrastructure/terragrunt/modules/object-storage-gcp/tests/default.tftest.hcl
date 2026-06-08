# -----------------------------------------------------------------------------
# object-storage-gcp module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: bucket_name + location flow into the
# single google_storage_bucket resource, and force_destroy stays pinned false.
# -----------------------------------------------------------------------------

mock_provider "google" {}

variables {
  bucket_name = "munchbox-test-bucket"
  location    = "US-CENTRAL1"
}

# -------------------------------------------------------------------------
# Inputs flow through to the single bucket resource
# -------------------------------------------------------------------------

run "inputs_flow_through" {
  command = plan

  # --- bucket_name passes through to resource.name ---
  assert {
    condition     = google_storage_bucket.this.name == var.bucket_name
    error_message = "bucket name must match var.bucket_name"
  }

  # --- location passes through to resource.location ---
  assert {
    condition     = google_storage_bucket.this.location == var.location
    error_message = "bucket location must match var.location"
  }
}

# -------------------------------------------------------------------------
# force_destroy pinned false (no var, no override)
# -------------------------------------------------------------------------

run "force_destroy_pinned_false" {
  command = plan

  # --- force_destroy is a literal constant in the module ---
  assert {
    condition     = google_storage_bucket.this.force_destroy == false
    error_message = "bucket force_destroy must be false (hardcoded)"
  }
}
