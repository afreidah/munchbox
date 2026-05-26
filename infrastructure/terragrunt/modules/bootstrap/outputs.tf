# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# NODE IDENTITY
# -----------------------------------------------------------------------------

output "name" {
  description = "Node name"
  value       = var.name
}

output "provider_type" {
  description = "Provider type used"
  value       = var.provider_type
}

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

output "network_id" {
  description = "Network/VPC/VCN ID"
  value       = var.create_network ? module.network[0].network_id : null
}

output "subnet_id" {
  description = "Subnet ID"
  value       = local.subnet_id
}

output "security_group_id" {
  description = "Security group ID"
  value       = local.security_group_id
}

# -----------------------------------------------------------------------------
# COMPUTE
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "Instance/VM ID"
  value       = module.compute.id
}

output "public_ip" {
  description = "Public IP address"
  value       = module.compute.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = module.compute.private_ip
}

output "wireguard_ip" {
  description = "WireGuard VPN IP address"
  value       = var.wireguard_address
}

# -----------------------------------------------------------------------------
# CONNECTION
# -----------------------------------------------------------------------------

output "ssh_connection_string" {
  description = "SSH connection command (via public IP)"
  value       = module.compute.ssh_connection_string
}

output "ssh_via_wireguard" {
  description = "SSH connection command (via WireGuard)"
  value       = "ssh ${var.docker_user}@${var.wireguard_address}"
}

# -----------------------------------------------------------------------------
# CLUSTER INFO
# -----------------------------------------------------------------------------

output "nomad_node_class" {
  description = "Nomad node class"
  value       = var.node_class
}

output "nomad_node_pool" {
  description = "Nomad node pool"
  value       = var.node_pool
}

output "datacenter" {
  description = "Datacenter name"
  value       = var.datacenter
}

# -----------------------------------------------------------------------------
# RAW MODULE OUTPUTS
# -----------------------------------------------------------------------------

output "network" {
  description = "Raw network module outputs"
  value       = var.create_network ? module.network[0] : null
}

output "compute" {
  description = "Raw compute module outputs"
  value       = module.compute
}

# -----------------------------------------------------------------------------
# CLOUD-INIT (for debugging)
# -----------------------------------------------------------------------------

output "cloud_init_script" {
  description = "Generated cloud-init script (sensitive)"
  value       = local.cloud_init_script
  sensitive   = true
}
