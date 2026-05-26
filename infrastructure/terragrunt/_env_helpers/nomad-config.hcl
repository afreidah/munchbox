# -----------------------------------------------------------------------------
# NOMAD-CONFIG MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Include this in terragrunt.hcl to manage cluster-level Nomad configuration:
# scheduler algorithm, preemption, memory oversubscription, and node pools.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//nomad-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.nomad_config_inputs
