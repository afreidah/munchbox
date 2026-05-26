# -------------------------------------------------------------------------------
# Object Storage Module Variables - Oracle Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Input variables for the OCI Object Storage module. Requires compartment and
# user OCIDs for bucket creation and S3 credential generation.
# -------------------------------------------------------------------------------

variable "compartment_id" {
  description = "OCI compartment OCID where the bucket will be created"
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID for creating S3 compatibility credentials"
  type        = string
}

variable "bucket_name" {
  description = "Name of the Object Storage bucket"
  type        = string
}

variable "region" {
  description = "OCI region for S3 endpoint URL construction"
  type        = string
}

variable "storage_tier" {
  description = "Storage tier for the bucket (Standard or Archive)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Archive"], var.storage_tier)
    error_message = "Storage tier must be Standard or Archive."
  }
}

variable "versioning_enabled" {
  description = "Enable object versioning on the bucket"
  type        = bool
  default     = false
}

variable "metadata" {
  description = "Custom metadata to attach to the bucket"
  type        = map(string)
  default     = {}
}
