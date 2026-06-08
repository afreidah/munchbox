# -----------------------------------------------------------------------------
# OBJECT-STORAGE-TIGRIS MODULE
# -----------------------------------------------------------------------------
#
# Manages an existing Tigris bucket backing s3-orchestrator. Bucket-only; the
# S3 credentials stay in Vault. No location block means a global bucket; add
# one only if the bucket is regional.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "tigris_bucket" "this" {
  bucket = var.bucket_name
}
