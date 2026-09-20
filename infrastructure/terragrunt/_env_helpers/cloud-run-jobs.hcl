# -----------------------------------------------------------------------------
# CLOUD-RUN-JOBS ENV HELPER
# -----------------------------------------------------------------------------
#
# Declares the consumers allowed to run containers on Cloud Run's free tier.
# Each gets a dispatcher identity with a key and a runtime identity its
# containers execute as, so a leaked dispatcher key cannot act as the workload
# and the workload holds nothing.
#
# The free tier is per project: 240,000 vCPU-seconds and 450,000 GiB-seconds a
# month, shared across everything declared here. Cloud Logging's 50 GiB a month
# is what makes this platform usable at all, since it is the only one of the
# three we looked at that returns a job's output through a free documented API.
#
# Keys land in Vault through _env_helpers/vault-secrets.hcl, not from here.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloud-run-jobs"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- one consumer per tool, not one shared identity ---
  #
  # vagabond brokers stateless CI onto free-tier cloud compute. Its jobs are
  # short-lived containers that run a command and exit, so nothing here
  # outlives an execution.
  consumers = {
    vagabond = {}
  }
}

inputs = {
  project   = local.root.locals.gcp_defaults.project
  region    = local.root.locals.gcp_defaults.region
  consumers = local.consumers
}
