# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR IDENTITIES LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "s3_orchestrator" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/s3-orchestrator.hcl"
  expose = true
}
