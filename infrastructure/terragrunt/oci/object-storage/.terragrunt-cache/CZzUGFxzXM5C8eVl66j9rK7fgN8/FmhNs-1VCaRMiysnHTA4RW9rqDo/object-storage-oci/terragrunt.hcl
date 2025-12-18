# -------------------------------------------------------------------------------
# OCI Object Storage - S3 Proxy Backend
#
# Project: Munchbox / Author: Alex Freidah
#
# Deploys an OCI Object Storage bucket for use as a backend in the unified S3
# proxy. Creates S3-compatible credentials via Customer Secret Keys for access.
#
# Required environment variables:
#   OCI_COMPARTMENT_ID - OCI compartment OCID
#   OCI_USER_OCID      - OCI user OCID (for creating S3 credentials)
#   OCI_REGION         - OCI region (e.g., us-ashburn-1)
# -------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infrastructure/terraform/modules//object-storage-oci"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  compartment_id     = get_env("OCI_COMPARTMENT_ID")
  user_ocid          = get_env("OCI_USER_OCID")
  region             = get_env("OCI_REGION", "us-ashburn-1")
  bucket_name        = "munchbox-s3-proxy"
  storage_tier       = "Standard"
  versioning_enabled = false

  metadata = {
    project    = "munchbox"
    managed_by = "terragrunt"
    purpose    = "s3-proxy-backend"
  }
}
