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
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//network"
}

# --- network dispatches to oci_networking / aws_networking / security-list-oci
#     / security-group via count, so those children can't carry their own
#     provider blocks. Providers must live at the leaf-cache root. ---
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

# --- checkov: skip the 2 OCI ingress checks that crash on the dynamic block, and
#     soft-fail the rest. The shared network module bundles AWS/proxmox resources
#     (count=0 here) plus intentional 0.0.0.0/0 ingress, so findings are expected. ---
generate "checkov_config" {
  path      = ".checkov.yaml"
  if_exists = "overwrite"
  contents  = "skip-check:\n  - CKV_OCI_19\n  - CKV_OCI_20\nsoft-fail: true\n"
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
