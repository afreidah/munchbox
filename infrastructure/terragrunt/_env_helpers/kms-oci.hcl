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
  # --- IAM users/groups must live in the tenancy root ---
  tenancy_ocid       = local.root.locals.oci_defaults.tenancy_ocid
  region             = local.root.locals.oci_defaults.region
  user_ocid          = local.root.locals.oci_defaults.user_ocid
  fingerprint        = local.root.locals.oci_defaults.fingerprint
  private_key        = get_env("OCI_PRIVATE_KEY", "")
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
