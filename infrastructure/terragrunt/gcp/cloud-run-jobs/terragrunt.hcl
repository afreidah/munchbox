# -----------------------------------------------------------------------------
# GCP CLOUD RUN JOBS LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "cloud_run_jobs" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/cloud-run-jobs.hcl"
  expose = true
}
