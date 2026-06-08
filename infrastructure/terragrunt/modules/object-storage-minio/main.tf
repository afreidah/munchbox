# -----------------------------------------------------------------------------
# OBJECT-STORAGE-MINIO BUCKET
# -----------------------------------------------------------------------------
#
# Manages a single bucket on a self-hosted MinIO / S3-compatible service via
# the aminueza/minio provider. Uses path-less S3-compat addressing and is
# lighter than aws_s3_bucket for services that don't implement every S3
# sub-API. Bucket-only; the provider is wired by the env_helper.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "minio_s3_bucket" "this" {
  bucket = var.bucket_name
}
