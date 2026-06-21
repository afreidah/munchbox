# -----------------------------------------------------------------------------
# KMS-OCI ENV HELPER
# -----------------------------------------------------------------------------
#
# OCI KMS vault + master key for HashiCorp Vault auto-unseal.
# DEFAULT vault + SOFTWARE protection = free tier.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//kms-oci"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  compartment_id = local.root.locals.oci_defaults.compartment_id
  # --- IAM users/groups must live in the tenancy root; falls back to compartment_id, which is the tenancy here ---
  tenancy_ocid       = get_env("OCI_TENANCY_OCID", local.root.locals.oci_defaults.compartment_id)
  region             = get_env("OCI_REGION")
  vault_display_name = "munchbox-vault-unseal"
  vault_type         = "DEFAULT"
  key_display_name   = "vault-auto-unseal-key"
  protection_mode    = "SOFTWARE"

  tags = {
    Project   = "munchbox"
    ManagedBy = "terragrunt"
    Purpose   = "vault-auto-unseal"
  }
}
