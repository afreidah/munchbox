# -----------------------------------------------------------------------------
# OCI KMS - HashiCorp Vault Auto-Unseal
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "kms" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/kms-oci.hcl"
  expose = true
}
