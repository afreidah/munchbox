# -----------------------------------------------------------------------------
# NOMAD CLUSTER ENVIRONMENT HELPER
# -----------------------------------------------------------------------------
# Wraps the nomad-cluster module, injecting input from root.hcl.
# Ensures scheduler config, namespaces, and node pools are declaratively applied.
# -----------------------------------------------------------------------------

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules/nomad-cluster"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  scheduler   = local.root.inputs.nomad_cluster.scheduler
  namespaces  = local.root.inputs.nomad_cluster.namespaces
  node_pools  = local.root.inputs.nomad_cluster.node_pools
}

