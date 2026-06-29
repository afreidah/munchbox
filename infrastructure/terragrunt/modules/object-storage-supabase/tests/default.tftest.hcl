# -----------------------------------------------------------------------------
# object-storage-supabase module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the module's only composition: project_ref, bucket_name, public,
# file_size_limit, and allowed_mime_types flow into the single
# supabase_storage_bucket resource, and that the optional limits default to
# null when omitted.
# -----------------------------------------------------------------------------

mock_provider "supabase" {}

variables {
  project_ref        = "abcdefghijklmnopqrst"
  bucket_name        = "munchbox-test-bucket"
  public             = true
  file_size_limit    = 52428800
  allowed_mime_types = ["image/png", "application/pdf"]
}

# -------------------------------------------------------------------------
# Inputs flow through to the single bucket resource
# -------------------------------------------------------------------------

run "inputs_flow_through" {
  command = plan

  # --- project_ref passes through to resource.project_ref ---
  assert {
    condition     = supabase_storage_bucket.this.project_ref == var.project_ref
    error_message = "bucket project_ref must match var.project_ref"
  }

  # --- bucket_name passes through to resource.name ---
  assert {
    condition     = supabase_storage_bucket.this.name == var.bucket_name
    error_message = "bucket name must match var.bucket_name"
  }

  # --- public passes through to resource.public ---
  assert {
    condition     = supabase_storage_bucket.this.public == var.public
    error_message = "bucket public must match var.public"
  }

  # --- file_size_limit passes through to resource.file_size_limit ---
  assert {
    condition     = supabase_storage_bucket.this.file_size_limit == var.file_size_limit
    error_message = "bucket file_size_limit must match var.file_size_limit"
  }

  # --- allowed_mime_types passes through to resource.allowed_mime_types ---
  assert {
    condition     = supabase_storage_bucket.this.allowed_mime_types == var.allowed_mime_types
    error_message = "bucket allowed_mime_types must match var.allowed_mime_types"
  }

  # --- output: bucket mirrors the bucket_name input ---
  assert {
    condition     = output.bucket == var.bucket_name
    error_message = "bucket output must match var.bucket_name"
  }
}

# -------------------------------------------------------------------------
# Optional limits default to null when omitted (private bucket)
# -------------------------------------------------------------------------

run "optional_limits_default_null" {
  command = plan

  variables {
    project_ref        = "abcdefghijklmnopqrst"
    bucket_name        = "munchbox-private-bucket"
    public             = false
    file_size_limit    = null
    allowed_mime_types = null
  }

  # --- public falls back to the unrestricted private default ---
  assert {
    condition     = supabase_storage_bucket.this.public == false
    error_message = "private bucket must render public = false"
  }

  # --- file_size_limit is null when no cap is requested ---
  assert {
    condition     = supabase_storage_bucket.this.file_size_limit == null
    error_message = "omitted file_size_limit must render null"
  }

  # --- allowed_mime_types is null when no restriction is requested ---
  assert {
    condition     = supabase_storage_bucket.this.allowed_mime_types == null
    error_message = "omitted allowed_mime_types must render null"
  }
}
