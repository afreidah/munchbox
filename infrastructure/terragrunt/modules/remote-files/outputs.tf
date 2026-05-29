# -----------------------------------------------------------------------------
# REMOTE-FILES MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "bundle_shas" {
  description = "sha256 per bundle of (content + destination + mode); changes when any file in the bundle changes."
  value       = local.bundle_shas
}

output "file_instances" {
  description = "Resolved (target/bundle/file) keys; useful for debugging fan-out."
  value       = sort(keys(local.file_instances))
}

output "restart_instances" {
  description = "Resolved (target/bundle) keys; one restart per pair."
  value       = sort(keys(local.bundle_instances))
}
