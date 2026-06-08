# -----------------------------------------------------------------------------
# OBJECT-STORAGE-TIGRIS Module Outputs
# -----------------------------------------------------------------------------

output "bucket" {
  description = "Tigris bucket name"
  value       = tigris_bucket.this.bucket
}
