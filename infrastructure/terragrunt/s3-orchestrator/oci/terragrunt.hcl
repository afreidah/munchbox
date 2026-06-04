# -------------------------------------------------------------------------------
# OCI Object Storage - S3 Orchestrator Backend
# -------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "object_storage_oci" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/object-storage-oci.hcl"
}
