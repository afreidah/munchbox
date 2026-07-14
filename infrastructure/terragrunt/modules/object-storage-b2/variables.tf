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

variable "lifecycle_rules" {
  description = <<-EOT
    B2 lifecycle rules that prune non-current file versions. B2 retains
    hidden/superseded versions (from overwrites and deletes) until a rule
    removes them, so high-churn backends need this to stay under the account
    storage cap. Set days_from_hiding_to_deleting (and leave
    days_from_uploading_to_hiding null) to keep only the current version and
    delete older ones. Empty = no rules (bucket managed as-is).
  EOT
  type = list(object({
    file_name_prefix                                       = string
    days_from_hiding_to_deleting                           = optional(number)
    days_from_uploading_to_hiding                          = optional(number)
    days_from_starting_to_canceling_unfinished_large_files = optional(number)
  }))
  default = []
}
