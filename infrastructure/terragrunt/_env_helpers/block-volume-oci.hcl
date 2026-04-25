# -----------------------------------------------------------------------------
# BLOCK-VOLUME-OCI MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Creates and attaches OCI block volumes to an existing instance. Config is
# looked up from root.hcl's block_volume_oci_configs map using the calling
# directory name as the key.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules//block-volume-oci"
}

locals {
  root     = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  dir_name = basename(get_terragrunt_dir())
  config   = local.root.locals.block_volume_oci_configs[local.dir_name]
}

dependency "instance" {
  config_path = "../${local.config.target_node}"

  mock_outputs = {
    instance_id = "mock-instance-id"
    compute = {
      oci = {
        availability_domain = "mock-AD-1"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  compartment_id      = local.root.locals.oci_defaults.compartment_id
  availability_domain = dependency.instance.outputs.compute.oci.availability_domain
  instance_id         = dependency.instance.outputs.instance_id
  volumes             = local.config.volumes

  tags = {
    Project   = "munchbox"
    ManagedBy = "terragrunt"
    Purpose   = local.config.purpose
  }
}
