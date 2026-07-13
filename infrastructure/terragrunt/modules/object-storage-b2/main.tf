# -------------------------------------------------------------------------------
# Object Storage Module - Backblaze B2
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages an existing Backblaze B2 bucket used as an s3-orchestrator backend.
# Bucket-only (like cloudflare-r2): the S3-compatible credentials stay in Vault
# as-is. Import the live bucket so Terraform tracks it without recreating.
# -------------------------------------------------------------------------------

resource "b2_bucket" "this" {
  bucket_name = var.bucket_name
  bucket_type = var.bucket_type

  # --- Prune non-current file versions. B2 keeps hidden/superseded versions
  #     (from every overwrite + delete) until a lifecycle rule removes them, so
  #     a high-churn backend like tempo-traces balloons the account's stored
  #     bytes -- and blows the storage cap -- even though the *current* object
  #     set stays tiny. Rules are opt-in per bucket via var.lifecycle_rules. ---
  dynamic "lifecycle_rules" {
    for_each = var.lifecycle_rules
    iterator = rule
    content {
      file_name_prefix                                       = rule.value.file_name_prefix
      days_from_hiding_to_deleting                           = rule.value.days_from_hiding_to_deleting
      days_from_uploading_to_hiding                          = rule.value.days_from_uploading_to_hiding
      days_from_starting_to_canceling_unfinished_large_files = rule.value.days_from_starting_to_canceling_unfinished_large_files
    }
  }
}
