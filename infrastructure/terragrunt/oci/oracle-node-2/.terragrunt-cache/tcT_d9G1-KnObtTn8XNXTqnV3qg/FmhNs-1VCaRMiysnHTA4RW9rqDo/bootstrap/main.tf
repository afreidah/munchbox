# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE
# -----------------------------------------------------------------------------
#
# High-level module that provisions a complete Munchbox cluster node:
# - Network (VPC/VCN or existing Proxmox bridge)
# - Compute (spot instance, OCI instance, or Proxmox VM)
# - Cloud-init bootstrap (WireGuard, Nomad, Consul, Docker)
#
# This is the "one module to rule them all" - deploy a fully configured
# cluster node on any supported provider with a single module call.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

module "network" {
  source = "../network"
  count  = var.create_network ? 1 : 0

  provider_type = var.provider_type
  name          = var.name
  vpc_cidr      = var.vpc_cidr

  allow_ssh       = var.allow_ssh
  allow_wireguard = var.allow_wireguard
  allow_icmp      = var.allow_icmp
  trusted_cidr    = var.wireguard_subnet

  aws_config     = var.aws_config != null ? { availability_zones = var.aws_config.availability_zones } : null
  oci_config     = var.oci_config != null ? { compartment_id = var.oci_config.compartment_id } : null
  proxmox_config = var.proxmox_config != null ? { network_bridge = try(var.proxmox_config.network_bridge, "vmbr0") } : null

  tags = var.tags
}

# -----------------------------------------------------------------------------
# CLOUD-INIT SCRIPT GENERATION
# -----------------------------------------------------------------------------

locals {
  # Generate cloud-init from template
  cloud_init_script = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    # WireGuard
    wireguard_private_key       = var.wireguard_private_key
    wireguard_address           = var.wireguard_address
    wireguard_server_public_key = var.wireguard_server_public_key
    wireguard_endpoint          = var.wireguard_endpoint
    wireguard_allowed_ips       = var.wireguard_allowed_ips

    # Cluster
    datacenter        = var.datacenter
    consul_retry_join = join(", ", [for s in var.consul_servers : "\"${s}\""])
    nomad_servers     = join(", ", [for s in var.nomad_servers : "\"${s}\""])

    # Node configuration
    node_class   = var.node_class
    node_pool    = var.node_pool
    node_meta    = var.node_meta
    provider_type = var.provider_type

    # Consul integration
    consul_integration = var.consul_integration

    # Docker
    allow_privileged_docker = var.allow_privileged_docker ? "true" : "false"
    docker_user             = var.docker_user

    # Versions
    consul_version = var.consul_version
    nomad_version  = var.nomad_version
  })

  # Determine subnet and security group IDs
  subnet_id = var.create_network ? module.network[0].subnet_id : var.existing_subnet_id
  security_group_id = var.create_network ? module.network[0].security_group_id : var.existing_security_group_id
}

# -----------------------------------------------------------------------------
# COMPUTE
# -----------------------------------------------------------------------------

module "compute" {
  source = "../compute"

  provider_type = var.provider_type
  name          = var.name
  cpu           = var.cpu
  memory_gb     = var.memory_gb
  disk_gb       = var.disk_gb
  ssh_key       = var.ssh_public_key
  user_data     = local.cloud_init_script

  aws_config = var.provider_type == "aws" ? {
    subnet_id          = local.subnet_id
    security_group_ids = var.existing_security_group_ids != null ? var.existing_security_group_ids : [local.security_group_id]
    instance_type      = try(var.aws_config.instance_type, null)
    architecture       = try(var.aws_config.architecture, "arm64")
    spot_type          = try(var.aws_config.spot_type, "persistent")
    assign_elastic_ip  = try(var.aws_config.assign_elastic_ip, false)
  } : null

  oci_config = var.provider_type == "oci" ? {
    compartment_id      = var.oci_config.compartment_id
    availability_domain = var.oci_config.availability_domain
    subnet_id           = local.subnet_id
    shape               = try(var.oci_config.shape, null)
  } : null

  proxmox_config = var.provider_type == "proxmox" ? {
    target_node    = var.proxmox_config.target_node
    vmid           = var.proxmox_config.vmid
    template_name  = try(var.proxmox_config.template_name, "debian-base")
    disk_storage   = try(var.proxmox_config.disk_storage, "local-lvm")
    network_bridge = try(var.proxmox_config.network_bridge, "vmbr0")
  } : null

  tags = var.tags
}
