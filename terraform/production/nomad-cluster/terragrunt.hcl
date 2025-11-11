# -----------------------------------------------------------------------------
# NOMAD CLUSTER - PROD ENVIRONMENT
# -----------------------------------------------------------------------------
# Applies the Nomad cluster configuration in the production environment.
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "nomad_cluster" {
  path = "${get_repo_root()}/terraform/_env_helpers/nomad-cluster.hcl"
}

