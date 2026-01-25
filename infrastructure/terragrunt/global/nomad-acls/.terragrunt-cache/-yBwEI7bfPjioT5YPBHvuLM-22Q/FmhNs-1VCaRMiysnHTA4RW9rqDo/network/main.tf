# -----------------------------------------------------------------------------
# UNIFIED NETWORK MODULE
# -----------------------------------------------------------------------------
#
# Multi-cloud/on-prem networking abstraction. Create VPCs/VCNs on AWS or
# Oracle Cloud, or reference existing Proxmox network bridges.
#
# Features:
#   - Unified interface: name, vpc_cidr, subnet_cidr
#   - Provider routing via `provider_type` variable
#   - Normalized outputs across all providers
#   - Includes security group/list creation with common presets
#
# Usage:
#   module "network" {
#     source = "../modules/network"
#
#     provider_type = "aws"  # or "oci" or "proxmox"
#     name          = "munchbox"
#     vpc_cidr      = "10.101.0.0/16"
#     subnet_cidr   = "10.101.1.0/24"
#
#     # Security presets
#     allow_ssh       = "0.0.0.0/0"
#     allow_wireguard = "0.0.0.0/0"
#     trusted_cidr    = "10.200.0.0/24"
#
#     # Provider-specific
#     aws_config = { availability_zones = ["us-east-1a"] }
#   }
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# LOCAL COMPUTATIONS
# -----------------------------------------------------------------------------

locals {
  is_aws     = var.provider_type == "aws"
  is_oci     = var.provider_type == "oci"
  is_proxmox = var.provider_type == "proxmox"

  # Auto-derive subnet CIDR from VPC CIDR if not explicitly compatible
  # This takes the first /24 block from the VPC (e.g., 10.100.0.0/16 -> 10.100.0.0/24)
  derived_subnet_cidr = cidrsubnet(var.vpc_cidr, 24 - parseint(split("/", var.vpc_cidr)[1], 10), 0)

  # Use provided subnet_cidr only if it's within the VPC, otherwise use derived
  effective_subnet_cidr = can(cidrsubnet(var.vpc_cidr, 0, 0)) && (
    tonumber(split(".", cidrhost(var.subnet_cidr, 0))[0]) == tonumber(split(".", cidrhost(var.vpc_cidr, 0))[0]) &&
    tonumber(split(".", cidrhost(var.subnet_cidr, 0))[1]) == tonumber(split(".", cidrhost(var.vpc_cidr, 0))[1])
  ) ? var.subnet_cidr : local.derived_subnet_cidr
}

# -----------------------------------------------------------------------------
# AWS NETWORKING
# -----------------------------------------------------------------------------

module "aws_networking" {
  source = "../networking"
  count  = local.is_aws ? 1 : 0

  name               = var.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.aws_config.availability_zones
  subnet_newbits     = coalesce(try(var.aws_config.subnet_newbits, null), 8)

  tags = var.tags
}

module "aws_security_group" {
  source = "../security-group"
  count  = local.is_aws ? 1 : 0

  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = module.aws_networking[0].vpc_id

  allow_ssh       = var.allow_ssh
  allow_wireguard = var.allow_wireguard
  allow_icmp      = var.allow_icmp
  trusted_cidr    = var.trusted_cidr
  ingress_rules   = var.additional_ingress_rules

  tags = var.tags
}

# -----------------------------------------------------------------------------
# OCI NETWORKING
# -----------------------------------------------------------------------------

module "oci_security_list" {
  source = "../security-list-oci"
  count  = local.is_oci ? 1 : 0

  name           = "${var.name}-sl"
  compartment_id = var.oci_config.compartment_id
  vcn_id         = module.oci_networking[0].vcn_id

  allow_ssh       = var.allow_ssh
  allow_wireguard = var.allow_wireguard
  allow_icmp      = var.allow_icmp
  trusted_cidr    = var.trusted_cidr
}

module "oci_networking" {
  source = "../networking-oci"
  count  = local.is_oci ? 1 : 0

  name              = var.name
  compartment_id    = var.oci_config.compartment_id
  vcn_cidr          = var.vpc_cidr
  subnet_cidr       = local.effective_subnet_cidr
  dns_label         = coalesce(try(var.oci_config.dns_label, null), replace(var.name, "/[^a-z0-9]/", ""))
  subnet_dns_label  = coalesce(try(var.oci_config.subnet_dns_label, null), "main")
  security_list_ids = [module.oci_security_list[0].security_list_id]
}

# -----------------------------------------------------------------------------
# PROXMOX "NETWORKING" (Reference existing bridge)
# -----------------------------------------------------------------------------

# Proxmox doesn't create networks via Terraform - bridges exist at host level
# This just provides consistent outputs for the unified interface

locals {
  proxmox_network_bridge = local.is_proxmox ? coalesce(try(var.proxmox_config.network_bridge, null), "vmbr0") : null
  proxmox_network_cidr   = local.is_proxmox ? coalesce(try(var.proxmox_config.network_cidr, null), "192.168.68.0/24") : null
}

# -----------------------------------------------------------------------------
# NORMALIZED OUTPUTS (via locals for aggregation)
# -----------------------------------------------------------------------------

locals {
  # Network/VPC ID
  network_id = (
    local.is_aws ? try(module.aws_networking[0].vpc_id, "") :
    local.is_oci ? try(module.oci_networking[0].vcn_id, "") :
    local.is_proxmox ? local.proxmox_network_bridge :
    ""
  )

  # Subnet ID(s)
  subnet_ids = (
    local.is_aws ? try(module.aws_networking[0].public_subnet_ids, []) :
    local.is_oci ? try([module.oci_networking[0].subnet_id], []) :
    local.is_proxmox ? [local.proxmox_network_bridge] :
    []
  )

  # Primary subnet (convenience)
  subnet_id = length(local.subnet_ids) > 0 ? local.subnet_ids[0] : ""

  # Security group/list ID
  security_group_id = (
    local.is_aws ? try(module.aws_security_group[0].security_group_id, "") :
    local.is_oci ? try(module.oci_security_list[0].security_list_id, "") :
    ""
  )

  # CIDR blocks
  vpc_cidr_block = (
    local.is_aws ? try(module.aws_networking[0].vpc_cidr, "") :
    local.is_oci ? try(module.oci_networking[0].vcn_cidr, "") :
    local.is_proxmox ? local.proxmox_network_cidr :
    ""
  )

  subnet_cidr_block = (
    local.is_aws ? try(module.aws_networking[0].public_subnet_cidrs[0], "") :
    local.is_oci ? try(module.oci_networking[0].subnet_cidr, "") :
    local.is_proxmox ? local.proxmox_network_cidr :
    ""
  )
}
