# -----------------------------------------------------------------------------
# IBM CLOUD OBJECT STORAGE ENV HELPER
# -----------------------------------------------------------------------------
#
# Creates an IBM Cloud Object Storage bucket with S3-compatible HMAC credentials.
#
# Required environment variables:
#   IC_API_KEY         - IBM Cloud API key
#   IBM_RESOURCE_GROUP - IBM Cloud resource group name (default: Default)
#   IBM_REGION         - IBM Cloud region (default: us-south)
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/object-storage-ibm"
}

inputs = {
  resource_group = get_env("IBM_RESOURCE_GROUP", "Default")
  instance_name  = "Cloud Object Storage-wx"
  region         = get_env("IBM_REGION", "us-south")
  bucket_name    = "munchbox-backup-storage"
  storage_class  = "standard"
  plan           = "standard"

  tags = {
    project    = "munchbox"
    managed_by = "terragrunt"
    purpose    = "backup-storage"
  }
}
