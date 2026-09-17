# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS ENV HELPER
# -----------------------------------------------------------------------------
#
# Points the module at the on-disk dashboards/ dir; the module discovers
# *.json there and pushes each to grafana via the API. Edit a JSON,
# terragrunt apply, no nomad redeploy and no consul-template delimiter
# escape ceremony.
#
# Bodies are loaded lazily by the module (file()) instead of passed inline
# through inputs -- the inline form blows ARG_MAX once the JSON corpus
# crosses ~1MB (node-exporter-full alone is 470KB).
#
# Auth + URL: grafana provider talks to the internal grafana endpoint
# (http://grafana.service.consul:3030) to bypass oauth2-proxy. Credentials
# come from TF_VAR_grafana_admin_{user,password} exported by munchbox-env.sh.
#
# The s3-orchestrator dashboard is not on disk here. It ships with the code it
# graphs, and a release publishes it to the artifact bucket, so this leaf reads
# it back at the pinned version rather than holding a second copy that drifts.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//grafana-dashboards"
}

# --- Supplies the keypair the dashboard is fetched with: an identity granted
#     list and read on the artifact bucket and nothing else. ---
dependency "s3_identities" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/apps/s3-orchestrator"

  mock_outputs = {
    credentials = {
      "artifacts_terragrunt_reader" = { access_key = "MOCKARTIFACTSACCESSKEY", secret_key = "mock-artifacts-secret-key" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]

  # --- The leaf has state, so a mock is only reached per-output: a key the
  #     state does not carry yet resolves to the mock rather than failing. ---
  mock_outputs_merge_strategy_with_state = "shallow"
}

locals {
  root      = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  artifacts = local.root.locals.s3_orchestrator_artifacts
}

inputs = {
  grafana_url            = "http://grafana.service.consul:3030"
  grafana_admin_user     = get_env("TF_VAR_grafana_admin_user", "")
  grafana_admin_password = get_env("TF_VAR_grafana_admin_password", "")
  dashboards_dir         = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/grafana-dashboards/dashboards"

  remote_dashboards = {
    "s3-orchestrator" = {
      bucket = local.artifacts.bucket
      key    = "s3-orchestrator/grafana/${local.root.locals.s3_orchestrator_version}/s3-orchestrator.json"
    }
  }

  artifact_store = {
    endpoint   = local.artifacts.endpoint
    access_key = dependency.s3_identities.outputs.credentials["artifacts_terragrunt_reader"].access_key
    secret_key = dependency.s3_identities.outputs.credentials["artifacts_terragrunt_reader"].secret_key
  }
}
