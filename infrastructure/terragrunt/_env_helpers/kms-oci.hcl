# -----------------------------------------------------------------------------
# KMS-OCI MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Include this in terragrunt.hcl to deploy OCI KMS vault and master encryption
# key for HashiCorp Vault auto-unseal functionality.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//kms-oci"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.kms_oci_inputs
