# -----------------------------------------------------------------------------
# object-storage-minio module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: bucket_name flows into the single
# minio_s3_bucket resource. The minio provider is the only one the resource
# references, so it is the only one mocked here.
# -----------------------------------------------------------------------------

mock_provider "minio" {}

variables {
  bucket_name = "munchbox-test-bucket"
}

# -------------------------------------------------------------------------
# Inputs flow through to the single bucket resource
# -------------------------------------------------------------------------

run "inputs_flow_through" {
  command = plan

  # --- bucket_name passes through to resource.bucket ---
  assert {
    condition     = minio_s3_bucket.this.bucket == var.bucket_name
    error_message = "bucket must match var.bucket_name"
  }

  # --- output: bucket mirrors the input ---
  assert {
    condition     = output.bucket == var.bucket_name
    error_message = "bucket output must match var.bucket_name"
  }
}
