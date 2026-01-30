# -----------------------------------------------------------------------------
# FORGEJO SECRETS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "repository_id" {
  description = "Numeric ID of the Forgejo repository"
  value       = data.forgejo_repository.repo.id
}

output "secrets_created" {
  description = "Names of secrets created in Forgejo"
  value       = [for s in forgejo_repository_action_secret.secrets : s.name]
}
