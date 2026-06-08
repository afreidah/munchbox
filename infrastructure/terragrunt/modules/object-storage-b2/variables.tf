# -------------------------------------------------------------------------------
# Object Storage Module Variables - Backblaze B2
# -------------------------------------------------------------------------------

variable "bucket_name" {
  description = "Name of the existing B2 bucket"
  type        = string
}

variable "bucket_type" {
  description = "B2 bucket visibility (allPrivate or allPublic)"
  type        = string
  default     = "allPrivate"

  validation {
    condition     = contains(["allPrivate", "allPublic"], var.bucket_type)
    error_message = "bucket_type must be allPrivate or allPublic."
  }
}
