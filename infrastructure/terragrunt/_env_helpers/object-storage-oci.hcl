# -----------------------------------------------------------------------------
# OCI OBJECT STORAGE ENV HELPER
# -----------------------------------------------------------------------------
#
# Provisions an OCI Object Storage bucket with S3-compatible Customer Secret
# Key credentials. Inputs are env-driven so the leaf is a thin two-include
# wrapper.
#
# Required environment variables:
#   OCI_COMPARTMENT_ID - OCI compartment OCID
#   OCI_USER_OCID      - OCI user OCID (for creating S3 credentials)
#   OCI_REGION         - OCI region (default: us-ashburn-1)
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//object-storage-oci"
}

inputs = {
  compartment_id     = get_env("OCI_COMPARTMENT_ID")
  user_ocid          = get_env("OCI_USER_OCID")
  region             = get_env("OCI_REGION", "us-ashburn-1")
  bucket_name        = "munchbox-s3-orchestrator"
  storage_tier       = "Standard"
  versioning_enabled = false

  metadata = {
    project    = "munchbox"
    managed_by = "terragrunt"
    purpose    = "s3-orchestrator-backend"
  }
}
