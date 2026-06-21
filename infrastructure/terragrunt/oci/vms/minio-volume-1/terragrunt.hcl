# -----------------------------------------------------------------------------
# OCI Block Volume - MinIO Data Storage (oracle-arm-1)
# -----------------------------------------------------------------------------
# All configuration lives in root.hcl under block_volume_oci_configs, keyed
# by this directory's name. Helper at _env_helpers/block-volume-oci.hcl
# performs the lookup and wires dependencies.
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/block-volume-oci.hcl"
  merge_strategy = "deep"
}
