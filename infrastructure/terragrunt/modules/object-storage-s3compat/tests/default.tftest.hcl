# -----------------------------------------------------------------------------
# object-storage-s3compat module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: bucket_name flows into the single
# aws_s3_bucket resource. The aws provider is mocked; the real endpoint and
# Vault-sourced creds are wired by the env_helper at deploy time.
# -----------------------------------------------------------------------------

mock_provider "aws" {}

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
    condition     = aws_s3_bucket.this.bucket == var.bucket_name
    error_message = "bucket must match var.bucket_name"
  }

  # --- output: bucket mirrors the input ---
  assert {
    condition     = output.bucket == var.bucket_name
    error_message = "bucket output must match var.bucket_name"
  }
}
