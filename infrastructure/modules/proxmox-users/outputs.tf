# -----------------------------------------------------------------------------
# PROXMOX-USERS MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "roles" {
  description = "Created role IDs"
  value       = { for k, v in proxmox_virtual_environment_role.role : k => v.role_id }
}

output "users" {
  description = "Created user IDs"
  value       = { for k, v in proxmox_virtual_environment_user.user : k => v.user_id }
}
