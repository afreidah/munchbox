# -----------------------------------------------------------------------------
# object-storage-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the bucket composition: bucket name + storage_tier flow through,
# access_type is pinned NoPublicAccess, object_events_enabled is on (CKV_OCI_7),
# versioning toggles via var.versioning_enabled, and the customer_secret_key
# follows the <bucket>-s3-access naming convention.
# -----------------------------------------------------------------------------

mock_provider "oci" {
  mock_data "oci_objectstorage_namespace" {
    defaults = { namespace = "test-namespace" }
  }
}

variables {
  compartment_id     = "ocid1.compartment.oc1..mock"
  user_ocid          = "ocid1.user.oc1..mock"
  region             = "us-ashburn-1"
  bucket_name        = "test-bucket"
  storage_tier       = "Standard"
  versioning_enabled = false
  metadata           = { project = "munchbox" }
}

# -------------------------------------------------------------------------
# Bucket inputs flow + hardening fields are pinned
# -------------------------------------------------------------------------

run "bucket_inputs_propagate" {
  command = plan

  # --- bucket name comes from var ---
  assert {
    condition     = oci_objectstorage_bucket.this.name == var.bucket_name
    error_message = "bucket name must match var.bucket_name"
  }

  # --- storage tier comes from var ---
  assert {
    condition     = oci_objectstorage_bucket.this.storage_tier == var.storage_tier
    error_message = "bucket storage_tier must match var.storage_tier"
  }

  # --- access_type is hardcoded NoPublicAccess for safety ---
  assert {
    condition     = oci_objectstorage_bucket.this.access_type == "NoPublicAccess"
    error_message = "bucket access_type must be NoPublicAccess (pinned)"
  }

  # --- object events hardening (CKV_OCI_7) ---
  assert {
    condition     = oci_objectstorage_bucket.this.object_events_enabled == true
    error_message = "object_events_enabled must be true (CKV_OCI_7 hardening)"
  }
}

# -------------------------------------------------------------------------
# Versioning toggle: false renders "Disabled"
# -------------------------------------------------------------------------

run "versioning_disabled" {
  command = plan

  # --- versioning_enabled = false maps to literal "Disabled" ---
  assert {
    condition     = oci_objectstorage_bucket.this.versioning == "Disabled"
    error_message = "versioning_enabled = false should render \"Disabled\""
  }
}

# -------------------------------------------------------------------------
# Versioning toggle: true renders "Enabled"
# -------------------------------------------------------------------------

run "versioning_enabled" {
  command = plan

  variables {
    versioning_enabled = true
  }

  # --- versioning_enabled = true maps to literal "Enabled" ---
  assert {
    condition     = oci_objectstorage_bucket.this.versioning == "Enabled"
    error_message = "versioning_enabled = true should render \"Enabled\""
  }
}

# -------------------------------------------------------------------------
# Customer secret key uses <bucket>-s3-access naming + user_id from var
# -------------------------------------------------------------------------

run "secret_key_naming" {
  command = plan

  # --- key display_name follows the convention ---
  assert {
    condition     = oci_identity_customer_secret_key.s3_credentials.display_name == "${var.bucket_name}-s3-access"
    error_message = "secret key display_name must follow <bucket>-s3-access convention"
  }

  # --- key is owned by the var.user_ocid identity ---
  assert {
    condition     = oci_identity_customer_secret_key.s3_credentials.user_id == var.user_ocid
    error_message = "secret key user_id must match var.user_ocid"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- make the computed secret key values known during plan ---
  override_resource {
    target          = oci_identity_customer_secret_key.s3_credentials
    override_during = plan
    values = {
      id  = "mock-access-key-id"
      key = "mock-secret-key"
    }
  }

  # --- bucket_name mirrors the input ---
  assert {
    condition     = output.bucket_name == var.bucket_name
    error_message = "output.bucket_name must equal var.bucket_name"
  }

  # --- bucket_namespace comes from the mocked namespace data source ---
  assert {
    condition     = output.bucket_namespace == "test-namespace"
    error_message = "output.bucket_namespace must be the namespace data source value"
  }

  # --- s3_endpoint is derived from namespace + region ---
  assert {
    condition     = output.s3_endpoint == "https://test-namespace.compat.objectstorage.${var.region}.oraclecloud.com"
    error_message = "output.s3_endpoint must be the namespace/region-derived endpoint URL"
  }

  # --- s3_bucket_url is endpoint + bucket name ---
  assert {
    condition     = output.s3_bucket_url == "https://test-namespace.compat.objectstorage.${var.region}.oraclecloud.com/${var.bucket_name}"
    error_message = "output.s3_bucket_url must be endpoint + bucket_name"
  }

  # --- s3_access_key is the customer secret key id (mocked) ---
  assert {
    condition     = output.s3_access_key == "mock-access-key-id"
    error_message = "output.s3_access_key must be the customer secret key id"
  }

  # --- s3_secret_key is the secret (sensitive, mocked) ---
  assert {
    condition     = nonsensitive(output.s3_secret_key) == "mock-secret-key"
    error_message = "output.s3_secret_key must be the customer secret key value"
  }
}
