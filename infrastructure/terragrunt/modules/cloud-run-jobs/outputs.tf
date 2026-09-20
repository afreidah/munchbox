# -----------------------------------------------------------------------------
# CLOUD-RUN-JOBS Module Outputs
#
# Project: Munchbox / Author: Alex Freidah
#
# vault_data carries the dispatcher key plus the coordinates it is useless
# without: which project to submit into, which region, and which identity the
# containers should run as.
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Per-consumer credentials and coordinates, for the vault-secrets leaf to write"
  sensitive   = true

  value = {
    for name, key in google_service_account_key.dispatcher : name => {
      # Google hands the key back base64-encoded; decoded here so Vault holds
      # the JSON a client library can consume directly.
      credentials_json = base64decode(key.private_key)

      project               = var.project
      region                = var.region
      dispatcher_email      = google_service_account.dispatcher[name].email
      runtime_account_email = google_service_account.runtime[name].email
    }
  }
}

output "dispatcher_emails" {
  description = "Dispatcher service account emails, keyed by consumer"
  value       = { for name, sa in google_service_account.dispatcher : name => sa.email }
}

output "runtime_emails" {
  description = "Runtime service account emails, keyed by consumer"
  value       = { for name, sa in google_service_account.runtime : name => sa.email }
}

output "enabled_services" {
  description = "APIs enabled on the project by this module"
  value       = [for s in google_project_service.this : s.service]
}
