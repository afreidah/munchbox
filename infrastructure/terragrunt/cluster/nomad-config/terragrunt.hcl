# -----------------------------------------------------------------------------
# Nomad Config - Scheduler Algorithm, Preemption, Memory Oversubscription,
# and Node Pools
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "nomad_config" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/nomad-config.hcl"
  expose = true
}
