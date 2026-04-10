# -----------------------------------------------------------------------------
# OCI NETWORKING
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "networking" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/networking-oci.hcl"
}
