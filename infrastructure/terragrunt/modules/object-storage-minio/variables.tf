# -----------------------------------------------------------------------------
# OBJECT-STORAGE-MINIO Module Variables
# -----------------------------------------------------------------------------

variable "bucket_name" {
  description = "Name of the existing bucket on the S3-compatible service"
  type        = string
}
