# -------------------------------------------------------------------------------
# Object Storage Module Variables - IBM Cloud
#
# Project: Munchbox / Author: Alex Freidah
#
# Input variables for the IBM Cloud Object Storage module. Requires a resource
# group and region for bucket creation and HMAC credential generation.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IBM PROVIDER AUTH
# -----------------------------------------------------------------------------

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key; sourced from IC_API_KEY via env_helper."
  type        = string
  sensitive   = true
}

variable "resource_group" {
  description = "IBM Cloud resource group name"
  type        = string
}

variable "instance_name" {
  description = "Name of the Cloud Object Storage instance"
  type        = string
}

variable "bucket_name" {
  description = "Name of the Object Storage bucket"
  type        = string
}

variable "region" {
  description = "IBM Cloud region for the bucket (e.g., us-south, eu-de)"
  type        = string
}

variable "plan" {
  description = "COS service plan (standard or lite)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "lite"], var.plan)
    error_message = "Plan must be standard or lite."
  }
}

variable "storage_class" {
  description = "Storage class for the bucket (standard, vault, cold, smart)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "vault", "cold", "smart"], var.storage_class)
    error_message = "Storage class must be standard, vault, cold, or smart."
  }
}

variable "tags" {
  description = "Tags to attach to the COS instance"
  type        = map(string)
  default     = {}
}
