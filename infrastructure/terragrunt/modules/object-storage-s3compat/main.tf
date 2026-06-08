# -----------------------------------------------------------------------------
# OBJECT-STORAGE-S3COMPAT MODULE
# -----------------------------------------------------------------------------
#
# Manages a single bucket on any S3-compatible service (IDrive e2, Synology C2,
# ...) via the aws provider pointed at the service endpoint by the consuming
# leaf. Bucket-only; the S3 creds stay in Vault and are wired by the env_helper.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}
