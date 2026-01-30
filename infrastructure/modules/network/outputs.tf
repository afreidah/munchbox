# -----------------------------------------------------------------------------
# UNIFIED NETWORK MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Normalized outputs that work regardless of which provider was used.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# NORMALIZED OUTPUTS
# -----------------------------------------------------------------------------

output "network_id" {
  description = "VPC ID (AWS), VCN ID (OCI), or bridge name (Proxmox)"
  value       = local.network_id
}

output "subnet_id" {
  description = "Primary subnet ID"
  value       = local.subnet_id
}

output "subnet_ids" {
  description = "List of all subnet IDs"
  value       = local.subnet_ids
}

output "security_group_id" {
  description = "Security group ID (AWS) or security list ID (OCI)"
  value       = local.security_group_id
}

output "vpc_cidr" {
  description = "VPC/VCN CIDR block"
  value       = local.vpc_cidr_block
}

output "subnet_cidr" {
  description = "Primary subnet CIDR block"
  value       = local.subnet_cidr_block
}

output "provider_type" {
  description = "Provider type used"
  value       = var.provider_type
}

# -----------------------------------------------------------------------------
# PROVIDER-SPECIFIC OUTPUTS
# -----------------------------------------------------------------------------

output "aws" {
  description = "Raw AWS networking outputs (null if not using AWS)"
  value = local.is_aws ? {
    vpc_id              = module.aws_networking[0].vpc_id
    vpc_cidr            = module.aws_networking[0].vpc_cidr
    public_subnet_ids   = module.aws_networking[0].public_subnet_ids
    public_subnet_cidrs = module.aws_networking[0].public_subnet_cidrs
    internet_gateway_id = module.aws_networking[0].internet_gateway_id
    route_table_id      = module.aws_networking[0].public_route_table_id
    security_group_id   = module.aws_security_group[0].security_group_id
    security_group_arn  = module.aws_security_group[0].security_group_arn
  } : null
}

output "oci" {
  description = "Raw OCI networking outputs (null if not using OCI)"
  value = local.is_oci ? {
    vcn_id              = module.oci_networking[0].vcn_id
    vcn_cidr            = module.oci_networking[0].vcn_cidr
    subnet_id           = module.oci_networking[0].subnet_id
    subnet_cidr         = module.oci_networking[0].subnet_cidr
    internet_gateway_id = module.oci_networking[0].internet_gateway_id
    route_table_id      = module.oci_networking[0].route_table_id
    security_list_id    = module.oci_security_list[0].security_list_id
  } : null
}

output "proxmox" {
  description = "Proxmox network info (null if not using Proxmox)"
  value = local.is_proxmox ? {
    network_bridge = local.proxmox_network_bridge
    network_cidr   = local.proxmox_network_cidr
  } : null
}
