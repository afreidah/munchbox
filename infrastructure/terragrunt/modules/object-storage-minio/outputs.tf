# -----------------------------------------------------------------------------
# OBJECT-STORAGE-MINIO Module Outputs
# -----------------------------------------------------------------------------

output "bucket" {
  description = "Bucket name"
  value       = minio_s3_bucket.this.bucket
}
