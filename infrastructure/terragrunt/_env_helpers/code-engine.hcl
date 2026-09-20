# -----------------------------------------------------------------------------
# CODE-ENGINE ENV HELPER
# -----------------------------------------------------------------------------
#
# Declares the IBM Code Engine projects the homelab dispatches container jobs
# to, one per consumer rather than one shared. Each gets its own Service ID and
# an API key that reaches only that project, so a leaked credential cannot start
# work anywhere else.
#
# The free tier is per account rather than per project, so splitting projects
# costs nothing and buys isolation: 100,000 vCPU-seconds and 200,000 GB-seconds
# a month are shared across everything declared here.
#
# Keys land in Vault through _env_helpers/vault-secrets.hcl, not from here.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//code-engine"
}

locals {
  # --- one project per consumer ---
  #
  # vagabond brokers stateless CI work onto free-tier cloud compute. Its jobs
  # are short-lived containers that run a test suite and exit, so nothing here
  # outlives a job run and the project holds no state between them.
  projects = {
    vagabond = {
      resource_group = get_env("IBM_RESOURCE_GROUP", "Default")

      tags = {
        project    = "munchbox"
        managed_by = "terragrunt"
        purpose    = "vagabond-compute-broker"
      }
    }
  }
}

inputs = {
  ibmcloud_api_key = get_env("IC_API_KEY", "")
  region           = get_env("IBM_REGION", "us-south")
  projects         = local.projects
}
