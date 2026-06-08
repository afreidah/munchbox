# -----------------------------------------------------------------------------
# OBJECT-STORAGE-S3COMPAT Module Outputs
# -----------------------------------------------------------------------------

output "bucket" {
  description = "Bucket name"
  value       = aws_s3_bucket.this.bucket
}
