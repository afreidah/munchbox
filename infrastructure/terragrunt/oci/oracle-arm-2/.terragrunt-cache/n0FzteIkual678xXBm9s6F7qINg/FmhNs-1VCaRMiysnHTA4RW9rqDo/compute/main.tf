# -----------------------------------------------------------------------------
# UNIFIED COMPUTE MODULE
# -----------------------------------------------------------------------------
#
# Multi-cloud/on-prem compute abstraction. Provision instances on AWS, Oracle
# Cloud, or Proxmox using a single interface.
#
# Features:
#   - Unified interface: cpu, memory_gb, disk_gb, ssh_key
#   - Provider routing via `provider_type` variable
#   - Normalized outputs across all providers
#   - Provider-specific config passed through when needed
#
# Usage:
#   module "node" {
#     source = "../modules/compute"
#
#     provider_type = "aws"  # or "oci" or "proxmox"
#     name          = "my-node"
#     cpu           = 2
#     memory_gb     = 4
#     disk_gb       = 20
#     ssh_key       = var.ssh_public_key
#
#     # Provider-specific (only relevant one is used)
#     aws_config     = { subnet_id = "...", security_group_ids = [...] }
#     oci_config     = { compartment_id = "...", availability_domain = "...", subnet_id = "..." }
#     proxmox_config = { target_node = "pve", vmid = 100 }
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

  # AWS instance type mapping (cpu + memory -> instance type)
  # Defaults to t4g (ARM) for cost efficiency
  aws_instance_type = var.aws_config != null ? coalesce(var.aws_config.instance_type, (
    var.memory_gb <= 1 ? "t4g.micro" :
    var.memory_gb <= 2 ? "t4g.small" :
    var.memory_gb <= 4 ? "t4g.medium" :
    var.memory_gb <= 8 ? "t4g.large" :
    "t4g.xlarge"
  )) : "t4g.medium"

  # OCI shape selection
  oci_shape = var.oci_config != null ? coalesce(var.oci_config.shape, (
    var.cpu == 1 && var.memory_gb <= 1 ? "VM.Standard.E2.1.Micro" : "VM.Standard.A1.Flex"
  )) : "VM.Standard.A1.Flex"

  # Is OCI using flexible shape?
  oci_is_flex = local.oci_shape == "VM.Standard.A1.Flex"
}

# -----------------------------------------------------------------------------
# AWS SPOT INSTANCE
# -----------------------------------------------------------------------------

module "aws" {
  source = "../compute-spot"
  count  = local.is_aws ? 1 : 0

  name               = var.name
  subnet_id          = var.aws_config.subnet_id
  security_group_ids = var.aws_config.security_group_ids

  instance_type    = local.aws_instance_type
  architecture     = coalesce(try(var.aws_config.architecture, null), "arm64")
  root_volume_size = var.disk_gb
  ssh_public_key   = var.ssh_key

  spot_type             = coalesce(try(var.aws_config.spot_type, null), "persistent")
  interruption_behavior = coalesce(try(var.aws_config.interruption_behavior, null), "stop")
  assign_elastic_ip     = coalesce(try(var.aws_config.assign_elastic_ip, null), false)
  user_data             = var.user_data

  tags = var.tags
}

# -----------------------------------------------------------------------------
# OCI INSTANCE
# -----------------------------------------------------------------------------

module "oci" {
  source = "../compute-oci"
  count  = local.is_oci ? 1 : 0

  name                = var.name
  compartment_id      = var.oci_config.compartment_id
  availability_domain = var.oci_config.availability_domain
  subnet_id           = var.oci_config.subnet_id

  shape          = local.oci_shape
  ocpus          = local.oci_is_flex ? var.cpu : null
  memory_gb      = local.oci_is_flex ? var.memory_gb : null
  boot_volume_gb = var.disk_gb >= 50 ? var.disk_gb : 50 # OCI minimum is 50GB
  ssh_public_key = var.ssh_key
  user_data      = var.user_data
}

# -----------------------------------------------------------------------------
# PROXMOX VM
# -----------------------------------------------------------------------------

module "proxmox" {
  source = "../compute-proxmox"
  count  = local.is_proxmox ? 1 : 0

  name        = var.name
  target_node = var.proxmox_config.target_node
  vmid        = var.proxmox_config.vmid

  cores     = var.cpu
  memory_mb = var.memory_gb * 1024
  disk_size = "${var.disk_gb}G"

  template_name  = coalesce(try(var.proxmox_config.template_name, null), "debian-base")
  disk_storage   = coalesce(try(var.proxmox_config.disk_storage, null), "local-lvm")
  network_bridge = coalesce(try(var.proxmox_config.network_bridge, null), "vmbr0")
  existing       = coalesce(try(var.proxmox_config.existing, null), false)
  qemu_agent     = coalesce(try(var.proxmox_config.qemu_agent, null), true)
  gpu_passthrough = try(var.proxmox_config.gpu_passthrough, null)
}

# -----------------------------------------------------------------------------
# NORMALIZED OUTPUTS (via locals for aggregation)
# -----------------------------------------------------------------------------

locals {
  # Aggregate outputs from whichever provider was used
  instance_id = coalesce(
    local.is_aws ? try(module.aws[0].spot_instance_id, "") : "",
    local.is_oci ? try(module.oci[0].instance_id, "") : "",
    local.is_proxmox ? try(tostring(module.proxmox[0].id), "") : "",
    ""
  )

  public_ip = coalesce(
    local.is_aws ? try(module.aws[0].public_ip, "") : "",
    local.is_oci ? try(module.oci[0].public_ip, "") : "",
    local.is_proxmox ? try(module.proxmox[0].default_ipv4_address, "") : "",
    ""
  )

  private_ip = coalesce(
    local.is_aws ? try(module.aws[0].private_ip, "") : "",
    local.is_oci ? try(module.oci[0].private_ip, "") : "",
    local.is_proxmox ? try(module.proxmox[0].default_ipv4_address, "") : "", # Proxmox uses same IP
    ""
  )

  ssh_connection_string = coalesce(
    local.is_aws ? try(module.aws[0].ssh_connection_string, "") : "",
    local.is_oci ? try(module.oci[0].ssh_connection_string, "") : "",
    local.is_proxmox ? try(module.proxmox[0].ssh_connection_string, "") : "",
    "ssh user@unknown"
  )
}
