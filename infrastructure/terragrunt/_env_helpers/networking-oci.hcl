# -----------------------------------------------------------------------------
# OCI NETWORKING ENV HELPER
# -----------------------------------------------------------------------------
#
# OCI VCN, subnet, internet gateway, and security list.
# Other OCI modules reference these outputs via terragrunt dependencies.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/modules//network"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  provider_type = "oci"
  name          = "oracle-node-1"
  vpc_cidr      = local.root.locals.network_cidrs.oci

  # Security presets
  allow_ssh       = "0.0.0.0/0"
  allow_wireguard = "0.0.0.0/0"
  allow_icmp      = "0.0.0.0/0"
  trusted_cidr    = local.root.locals.wireguard_subnet

  # OCI-specific
  oci_config = {
    compartment_id   = local.root.locals.oci_defaults.compartment_id
    dns_label        = "oraclenode1"
    subnet_dns_label = "main"
  }

  tags = {
    Project   = "munchbox"
    ManagedBy = "terragrunt"
    Purpose   = "oci-networking"
  }
}
