# -----------------------------------------------------------------------------
# OBJECT-STORAGE-GCP Module Outputs
# -----------------------------------------------------------------------------

output "bucket_name" {
  description = "GCS bucket name"
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "GCS bucket URL (gs://)"
  value       = google_storage_bucket.this.url
}
