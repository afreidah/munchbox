# -------------------------------------------------------------------------------
# Object Storage Module - Backblaze B2
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages an existing Backblaze B2 bucket used as an s3-orchestrator backend.
# Bucket-only (like cloudflare-r2): the S3-compatible credentials stay in Vault
# as-is. Import the live bucket so Terraform tracks it without recreating.
# -------------------------------------------------------------------------------

resource "b2_bucket" "this" {
  bucket_name = var.bucket_name
  bucket_type = var.bucket_type
}
