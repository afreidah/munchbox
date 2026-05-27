# -------------------------------------------------------------------------------
# Object Storage Module - Oracle Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Provisions an OCI Object Storage bucket with S3-compatible access credentials.
# Creates a Customer Secret Key for S3 API access, enabling standard S3 clients
# to interact with OCI Object Storage via the S3 Compatibility API.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# DATA SOURCES
# -------------------------------------------------------------------------

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

# -------------------------------------------------------------------------
# OBJECT STORAGE BUCKET
# -------------------------------------------------------------------------

resource "oci_objectstorage_bucket" "this" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = var.storage_tier

  versioning = var.versioning_enabled ? "Enabled" : "Disabled"

  # --- emit change events to OCI Events service (CKV_OCI_7); free unless subscribed ---
  object_events_enabled = true

  metadata = var.metadata
}

# -------------------------------------------------------------------------
# S3 COMPATIBILITY CREDENTIALS
# -------------------------------------------------------------------------

# Customer Secret Keys provide S3-compatible access to OCI Object Storage.
# The access_key is the key ID, and the secret_key is generated on creation.
resource "oci_identity_customer_secret_key" "s3_credentials" {
  display_name = "${var.bucket_name}-s3-access"
  user_id      = var.user_ocid
}
