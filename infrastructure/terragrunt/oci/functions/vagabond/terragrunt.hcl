# -----------------------------------------------------------------------------
# OCI FUNCTIONS - VAGABOND LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "functions" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/functions-oci.hcl"
}
