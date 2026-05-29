# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Include this in node-specific terragrunt.hcl files to deploy a complete
# Munchbox cluster node using the bootstrap module. Inputs are assembled
# from project-wide locals in root.hcl (network, ssh, wireguard, consul/
# nomad server lists), bootstrap-shape constants (chef server, cinc
# version, vault paths for validator/data-bag), and the node's own
# node.yaml + directory name.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  # --- double-slash: copy whole modules/ but use bootstrap as root ---
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//bootstrap"
}

# --- bootstrap calls module.network / module.compute with count, which
#     forbids those children from carrying their own provider {} blocks.
#     Providers must live at the leaf-cache root and inherit down through
#     the whole count-tree, so we generate them here rather than in any
#     individual module's providers.tf. ---
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "oci" {}

    provider "proxmox" {
      pm_tls_insecure = true
    }

    provider "aws" {
      region = "us-east-1"

      skip_credentials_validation = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_region_validation      = true

      default_tags {
        tags = {
          Project   = "munchbox"
          ManagedBy = "terragrunt"
        }
      }
    }
  EOF
}

# --- network source: sibling node (when node.yaml.share_network_from is set)
#     or sibling networking/ folder otherwise. Both export subnet_id + security_group_id. ---
dependency "network_source" {
  config_path = local.share_network_from != "" ? "${dirname(get_original_terragrunt_dir())}/${local.share_network_from}" : "${dirname(get_original_terragrunt_dir())}/networking"

  mock_outputs = {
    subnet_id         = "mock-subnet-id"
    security_group_id = "mock-security-group-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- per-node config loaded from <node-dir>/node.yaml ---
  node_config_path = "${get_terragrunt_dir()}/node.yaml"
  node_config      = yamldecode(file(local.node_config_path))

  # --- optional: borrow subnet + SG from another node instead of a fresh networking sibling ---
  share_network_from = try(local.node_config.share_network_from, "")

  provider_type = local.root.locals.provider_type

  # --- per-provider config: merge defaults from root with node overrides ---
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

inputs = {
  # --- Cluster-wide defaults pulled from root.hcl ---
  ssh_public_key = local.root.locals.ssh_public_key

  wireguard_subnet            = local.root.locals.wireguard_subnet
  wireguard_server_public_key = local.root.locals.wireguard_server_public_key
  wireguard_endpoint          = local.root.locals.wireguard_endpoint
  wireguard_allowed_ips       = "${local.root.locals.network_cidrs.wireguard}, ${local.root.locals.network_cidrs.homelab}"

  consul_servers = local.root.locals.consul_servers
  nomad_servers  = local.root.locals.nomad_servers

  # --- Legacy direct-install software versions (chef cookbooks pin their own) ---
  consul_version          = "1.17.0"
  nomad_version           = "1.7.0"
  allow_privileged_docker = false
  docker_user             = "ubuntu"

  # --- Chef bootstrap (cloud-init path; cookbooks take over after first converge) ---
  chef_server_url            = "https://cinc-server.munchbox.cc/organizations/munchbox"
  chef_validator_client_name = "munchbox-validator"
  cinc_version               = "19.2.12"

  chef_validator_vault_mount       = "secret"
  chef_validator_vault_name        = "cinc/validator"
  chef_validator_vault_field       = "pem"
  chef_data_bag_secret_vault_mount = "secret"
  chef_data_bag_secret_vault_name  = "cinc/encrypted_data_bag_secret"
  chef_data_bag_secret_vault_field = "value"

  hosts_overrides = {
    "cinc-server.munchbox.cc" = "192.168.68.99"
  }

  # --- Required from path/node config ---
  provider_type = local.provider_type
  name          = try(local.node_config.name, local.root.locals.node_name)

  # --- Compute shape: node.yaml with defaults ---
  cpu       = try(local.node_config.cpu, 2)
  memory_gb = try(local.node_config.memory_gb, 4)
  disk_gb   = try(local.node_config.disk_gb, 20)

  # --- WireGuard per-node ---
  wireguard_address     = local.node_config.wireguard_address
  wireguard_private_key = get_env("WG_PRIVATE_KEY_${upper(replace(local.root.locals.node_name, "-", "_"))}", "")

  # --- Optional node-level overrides ---
  datacenter = try(local.node_config.datacenter, local.root.locals.default_datacenter)
  node_class = try(local.node_config.node_class, local.root.locals.default_node_class)
  node_pool  = try(local.node_config.node_pool, "")
  node_meta  = try(local.node_config.node_meta, {})

  # --- Network ---
  create_network              = try(local.node_config.create_network, false)
  vpc_cidr                    = try(local.node_config.vpc_cidr, local.root.locals.network_cidrs[local.provider_type])
  existing_subnet_id          = dependency.network_source.outputs.subnet_id
  existing_security_group_id  = dependency.network_source.outputs.security_group_id
  existing_security_group_ids = try(local.node_config.existing_security_group_ids, null)

  # --- Provider-specific configs (merged above) ---
  aws_config     = local.aws_config
  oci_config     = local.oci_config
  proxmox_config = local.proxmox_config

  # --- Per-node chef bootstrap values ---
  # chef_node_name defaults to hyphen-stripped node_name (matches roles/nodes/<n>.rb)
  chef_node_name = try(local.node_config.chef_node_name, replace(local.root.locals.node_name, "-", ""))
  chef_run_list  = try(local.node_config.chef_run_list, "role[${replace(local.root.locals.node_name, "-", "_")}]")
  # Oracle/cloud nodes need wg0 to reach 192.168.68.x; proxmox/bare-metal already on the LAN.
  bootstrap_wireguard = try(local.node_config.bootstrap_wireguard, local.provider_type != "proxmox")

  # --- Optional static IP via netplan (proxmox VMs commonly pin DHCP-allocated IPs) ---
  static_ip           = try(local.node_config.static_ip, "")
  static_netmask_bits = try(local.node_config.static_netmask_bits, 24)
  gateway             = try(local.node_config.gateway, "")
  dns_servers         = try(local.node_config.dns_servers, [])
  network_interface   = try(local.node_config.network_interface, "ens18")

  # --- Tags: module default + node overrides ---
  tags = merge(
    {
      Project   = "munchbox"
      ManagedBy = "terragrunt"
    },
    try(local.node_config.tags, {}),
  )

  # --- Munchbox PKI passed as vars; the env_helper runs from the in-repo
  #     leaf so it can reach across into the chef cookbook tree (the
  #     terragrunt-cache copy of the bootstrap module can't).
  munchbox_root_ca         = file("${get_repo_root()}/infrastructure/cinc/cookbooks/munchbox_base/files/default/munchbox-root-ca.crt")
  munchbox_intermediate_ca = file("${get_repo_root()}/infrastructure/cinc/cookbooks/munchbox_base/files/default/munchbox-intermediate-ca.crt")
}
