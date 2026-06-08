# -----------------------------------------------------------------------------
# OBJECT-STORAGE-SUPABASE Module Variables
# -----------------------------------------------------------------------------

variable "project_ref" {
  description = "Supabase project reference ID"
  type        = string
}

variable "bucket_name" {
  description = "Storage bucket name"
  type        = string
}

variable "public" {
  description = "Whether the bucket is publicly accessible"
  type        = bool
  default     = false
}

variable "file_size_limit" {
  description = "Max object size in bytes (null = no limit)"
  type        = number
  default     = null
}

variable "allowed_mime_types" {
  description = "Allowed MIME types (null = no restriction)"
  type        = list(string)
  default     = null
}
