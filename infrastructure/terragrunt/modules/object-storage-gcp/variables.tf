# -----------------------------------------------------------------------------
# OBJECT-STORAGE-GCP Module Variables
# -----------------------------------------------------------------------------

variable "bucket_name" {
  description = "Name of the existing GCS bucket"
  type        = string
}

variable "location" {
  description = "GCS bucket location (e.g. US, US-CENTRAL1). Must match the live bucket or import forces a replacement."
  type        = string
}
