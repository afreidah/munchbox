# -----------------------------------------------------------------------------
# CODE-ENGINE Module Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# vault_data carries everything a consumer needs to reach the project: the API
# key it exchanges for a bearer token, plus the project id and region that the
# endpoint URL is built from. Those two are identifiers rather than secrets, but
# they travel with the key because a key without them reaches nothing.
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Per-project credentials and coordinates, for the vault-secrets leaf to write"
  sensitive   = true

  value = {
    for name, project in ibm_code_engine_project.this : name => {
      api_key    = ibm_iam_service_api_key.this[name].apikey
      project_id = project.project_id
      region     = var.region
      endpoint   = "https://api.${var.region}.codeengine.cloud.ibm.com/v2"
    }
  }
}

output "project_ids" {
  description = "Code Engine project GUIDs, keyed by project name"
  value       = { for name, project in ibm_code_engine_project.this : name => project.project_id }
}

output "service_id_names" {
  description = "Service ID names created for each project, keyed by project name"
  value       = { for name, id in ibm_iam_service_id.this : name => id.name }
}
