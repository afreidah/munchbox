# -----------------------------------------------------------------------------
# object-storage-b2 module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: bucket_name + bucket_type flow into
# the single b2_bucket resource, and that bucket_type defaults to allPrivate.
# -----------------------------------------------------------------------------

mock_provider "b2" {}

variables {
  bucket_name = "munchbox-test-bucket"
}

# -------------------------------------------------------------------------
# Inputs flow through to the single bucket resource
# -------------------------------------------------------------------------

run "inputs_flow_through" {
  command = plan

  variables {
    bucket_type = "allPublic"
  }

  # --- bucket_name passes through to resource.bucket_name ---
  assert {
    condition     = b2_bucket.this.bucket_name == var.bucket_name
    error_message = "bucket name must match var.bucket_name"
  }

  # --- bucket_type passes through to resource.bucket_type ---
  assert {
    condition     = b2_bucket.this.bucket_type == var.bucket_type
    error_message = "bucket type must match var.bucket_type"
  }
}

# -------------------------------------------------------------------------
# bucket_type defaults to allPrivate when unset
# -------------------------------------------------------------------------

run "bucket_type_defaults_private" {
  command = plan

  # --- default visibility is allPrivate ---
  assert {
    condition     = b2_bucket.this.bucket_type == "allPrivate"
    error_message = "bucket_type must default to allPrivate"
  }
}
