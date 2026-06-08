# -----------------------------------------------------------------------------
# OBJECT-STORAGE-SUPABASE Module Outputs
# -----------------------------------------------------------------------------

output "bucket" {
  description = "Bucket name"
  value       = supabase_storage_bucket.this.name
}
