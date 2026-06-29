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

  # surface the computed url during plan so the output assert can read it
  override_resource {
    target          = google_storage_bucket.this
    override_during = plan
    values = {
      url = "gs://munchbox-test-bucket"
    }
  }

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

  # --- output: bucket_name mirrors the input ---
  assert {
    condition     = output.bucket_name == var.bucket_name
    error_message = "bucket_name output must match var.bucket_name"
  }

  # --- output: bucket_url is computed (mocked) -> assert it surfaces ---
  assert {
    condition     = output.bucket_url == "gs://munchbox-test-bucket"
    error_message = "bucket_url output must surface the resource url"
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
