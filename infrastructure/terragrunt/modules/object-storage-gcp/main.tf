# -----------------------------------------------------------------------------
# OBJECT-STORAGE-GCP Bucket
# -----------------------------------------------------------------------------
#
# Manages an existing GCS bucket backing s3-orchestrator. Bucket-only -- the
# S3-interop HMAC creds stay in Vault. Minimal config so importing the live
# bucket converges; project comes from the provider (GOOGLE_PROJECT env).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "this" {
  name          = var.bucket_name
  location      = var.location
  force_destroy = false
}
