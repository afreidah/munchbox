# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE
# -----------------------------------------------------------------------------
#
# High-level module that provisions a Munchbox cluster node:
# - Network (VPC/VCN or existing Proxmox bridge)
# - Compute (spot instance, OCI instance, or Proxmox VM)
# - Chef-bootstrap cloud-init (optional WireGuard wg0 for oracle nodes,
#   trust the munchbox PKI, install cinc-client, run the first converge
#   against the node's role -- everything else lives in chef cookbooks).
#
# Pre-provision workflow (do these BEFORE `terragrunt apply`):
#   1. Mint AppRole secret_id from auth/chef-approle/role/chef-managed-node;
#      store at secret/chef-approle/secret-ids/<node>.
#   2. Upload the encrypted vault_agent data-bag item to chef-server:
#        infrastructure/cinc/scripts/upload-vault-agent-data-bag.sh <node>
#   3. Upload the per-node role file:
#        knife role from file infrastructure/cinc/roles/nodes/<node>.rb
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

# -----------------------------------------------------------------------------
# CHEF BOOTSTRAP SECRETS FROM VAULT
#
# Pulled at terragrunt apply time. The vault provider is generated for
# every terragrunt module by root.hcl; see modules/vault-config and
# modules/vaultwarden-secrets for prior art.
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "chef_validator" {
  mount = var.chef_validator_vault_mount
  name  = var.chef_validator_vault_name
}

data "vault_kv_secret_v2" "chef_data_bag_secret" {
  mount = var.chef_data_bag_secret_vault_mount
  name  = var.chef_data_bag_secret_vault_name
}

locals {
  # --- Chef-bootstrap cloud-init. WireGuard, static IP, and host-pins are conditional. ---
  cloud_init_script = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    # --- WireGuard (oracle nodes only; set bootstrap_wireguard = false on proxmox/bare-metal) ---
    bootstrap_wireguard         = var.bootstrap_wireguard
    wireguard_private_key       = var.wireguard_private_key
    wireguard_address           = var.wireguard_address
    wireguard_server_public_key = var.wireguard_server_public_key
    wireguard_endpoint          = var.wireguard_endpoint
    wireguard_allowed_ips       = var.wireguard_allowed_ips

    # --- Munchbox PKI (passed in via vars; the env_helper reads from the chef
    #     cookbook so there's one source of truth, and terragrunt-cache copies
    #     of this module can't reach across to infrastructure/cinc/). ---
    munchbox_root_ca         = var.munchbox_root_ca
    munchbox_intermediate_ca = var.munchbox_intermediate_ca

    # --- /etc/hosts pin so the node can reach cinc-server before consul::dns runs ---
    hosts_overrides = var.hosts_overrides

    # --- Chef-server registration. Secrets pulled from Vault data sources above. ---
    chef_server_url                = var.chef_server_url
    chef_node_name                 = var.chef_node_name
    chef_validator_client_name     = var.chef_validator_client_name
    chef_validator_key             = data.vault_kv_secret_v2.chef_validator.data[var.chef_validator_vault_field]
    chef_encrypted_data_bag_secret = data.vault_kv_secret_v2.chef_data_bag_secret.data[var.chef_data_bag_secret_vault_field]
    chef_run_list                  = var.chef_run_list
    cinc_version                   = var.cinc_version

    # --- Optional static IP via netplan (empty string skips entirely) ---
    static_ip           = var.static_ip
    static_netmask_bits = var.static_netmask_bits
    gateway             = var.gateway
    dns_servers         = var.dns_servers
    network_interface   = var.network_interface
  })

  # Determine subnet and security group IDs
  subnet_id         = var.create_network ? module.network[0].subnet_id : var.existing_subnet_id
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
