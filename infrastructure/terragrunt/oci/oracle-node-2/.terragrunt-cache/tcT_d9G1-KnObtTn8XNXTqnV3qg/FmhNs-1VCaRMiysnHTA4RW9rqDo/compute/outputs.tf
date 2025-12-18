# -----------------------------------------------------------------------------
# UNIFIED COMPUTE MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Normalized outputs that work regardless of which provider was used.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "id" {
  description = "Instance/VM ID"
  value       = local.instance_id
}

output "public_ip" {
  description = "Public IP address"
  value       = local.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = local.private_ip
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = local.ssh_connection_string
}

output "provider_type" {
  description = "Provider type used"
  value       = var.provider_type
}

output "name" {
  description = "Instance name"
  value       = var.name
}

# -----------------------------------------------------------------------------
# PROVIDER-SPECIFIC OUTPUTS (for when you need the raw module output)
# -----------------------------------------------------------------------------

output "aws" {
  description = "Raw AWS module outputs (null if not using AWS)"
  value       = local.is_aws ? module.aws[0] : null
}

output "oci" {
  description = "Raw OCI module outputs (null if not using OCI)"
  value       = local.is_oci ? module.oci[0] : null
}

output "proxmox" {
  description = "Raw Proxmox module outputs (null if not using Proxmox)"
  value       = local.is_proxmox ? module.proxmox[0] : null
}
