# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Include this in node-specific terragrunt.hcl files to deploy a complete
# Munchbox cluster node using the bootstrap module.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  # Double-slash copies entire modules dir but uses bootstrap as root
  source = "${get_repo_root()}/infrastructure/modules//bootstrap"
}

dependency "networking" {
  config_path = "${dirname(get_original_terragrunt_dir())}/networking"

  mock_outputs = {
    subnet_id         = "mock-subnet-id"
    security_group_id = "mock-security-group-id"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

locals {
  # Get root config
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # Node-specific config (loaded from node.yaml in the node's directory)
  node_config_path = "${get_terragrunt_dir()}/node.yaml"
  node_config      = yamldecode(file(local.node_config_path))

  # Determine provider from path
  provider_type = local.root.locals.provider_type

  # Build provider-specific config based on provider_type
  aws_config = local.provider_type == "aws" ? merge(
    local.root.locals.aws_defaults,
    try(local.node_config.aws_config, {})
  ) : null

  oci_config = local.provider_type == "oci" ? merge(
    local.root.locals.oci_defaults,
    try(local.node_config.oci_config, {})
  ) : null

  proxmox_config = local.provider_type == "proxmox" ? merge(
    local.root.locals.proxmox_defaults,
    try(local.node_config.proxmox_config, {})
  ) : null
}

inputs = merge(
  local.root.locals.bootstrap_inputs,
  {
    # Required - from path parsing or node config
    provider_type = local.provider_type
    name          = try(local.node_config.name, local.root.locals.node_name)

    # Compute resources - from node config with defaults
    cpu       = try(local.node_config.cpu, 2)
    memory_gb = try(local.node_config.memory_gb, 4)
    disk_gb   = try(local.node_config.disk_gb, 20)

    # WireGuard - must be specified per node
    wireguard_address     = local.node_config.wireguard_address
    wireguard_private_key = get_env("WG_PRIVATE_KEY_${upper(replace(local.root.locals.node_name, "-", "_"))}", "")

    # Optional overrides from node config
    datacenter = try(local.node_config.datacenter, local.root.locals.default_datacenter)
    node_class = try(local.node_config.node_class, local.root.locals.default_node_class)
    node_pool  = try(local.node_config.node_pool, "")
    node_meta  = try(local.node_config.node_meta, {})

    # Network config
    create_network              = try(local.node_config.create_network, false)
    vpc_cidr                    = try(local.node_config.vpc_cidr, local.root.locals.network_cidrs[local.provider_type])
    existing_subnet_id          = dependency.networking.outputs.subnet_id
    existing_security_group_id  = dependency.networking.outputs.security_group_id
    existing_security_group_ids = try(local.node_config.existing_security_group_ids, null)

    # Provider-specific configs
    aws_config     = local.aws_config
    oci_config     = local.oci_config
    proxmox_config = local.proxmox_config

    # Additional tags from node config
    tags = merge(
      local.root.locals.bootstrap_inputs.tags,
      try(local.node_config.tags, {})
    )
  }
)
