# -------------------------------------------------------------------------------
# Object Storage Module Outputs - Backblaze B2
# -------------------------------------------------------------------------------

output "bucket_id" {
  description = "B2 bucket ID"
  value       = b2_bucket.this.bucket_id
}

output "bucket_name" {
  description = "B2 bucket name"
  value       = b2_bucket.this.bucket_name
}
