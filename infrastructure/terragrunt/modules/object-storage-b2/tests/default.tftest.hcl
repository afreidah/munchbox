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

  # surface the computed bucket_id during plan so the output assert can read it
  override_resource {
    target          = b2_bucket.this
    override_during = plan
    values = {
      bucket_id = "mock-bucket-id"
    }
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

  # --- output: bucket_name mirrors the input ---
  assert {
    condition     = output.bucket_name == var.bucket_name
    error_message = "bucket_name output must match var.bucket_name"
  }

  # --- output: bucket_id is computed (mocked) -> assert it surfaces ---
  assert {
    condition     = output.bucket_id == "mock-bucket-id"
    error_message = "bucket_id output must surface the resource bucket_id"
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

# -------------------------------------------------------------------------
# lifecycle_rules flow through to the bucket's version-pruning rules
# -------------------------------------------------------------------------

run "lifecycle_rules_flow_through" {
  command = plan

  variables {
    lifecycle_rules = [{
      file_name_prefix             = ""
      days_from_hiding_to_deleting = 1
    }]
  }

  # --- exactly one rule is configured on the bucket ---
  assert {
    condition     = length(b2_bucket.this.lifecycle_rules) == 1
    error_message = "one lifecycle rule must be configured"
  }

  # --- hidden-version retention flows through ---
  assert {
    condition     = one(b2_bucket.this.lifecycle_rules).days_from_hiding_to_deleting == 1
    error_message = "days_from_hiding_to_deleting must flow through to the bucket"
  }
}

# -------------------------------------------------------------------------
# lifecycle_rules default to none (bucket managed as-is)
# -------------------------------------------------------------------------

run "lifecycle_rules_default_empty" {
  command = plan

  # --- no rules unless explicitly set ---
  assert {
    condition     = length(b2_bucket.this.lifecycle_rules) == 0
    error_message = "lifecycle_rules must default to empty"
  }
}
