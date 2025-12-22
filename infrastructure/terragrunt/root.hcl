# -----------------------------------------------------------------------------
# MUNCHBOX TERRAGRUNT ROOT CONFIGURATION
# -----------------------------------------------------------------------------
#
# Centralized configuration for all Munchbox infrastructure deployments.
# Environment-specific terragrunt.hcl files include this + their env_helper.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # PATH PARSING
  # ---------------------------------------------------------------------------
  # Parse the directory structure to determine provider and node name
  # Expected structure: terragrunt/<provider>/<node_name>/terragrunt.hcl

  # get_original_terragrunt_dir() returns the dir of the file that initiated the include
  terragrunt_dir = get_original_terragrunt_dir()
  node_name      = basename(local.terragrunt_dir)
  provider_type  = basename(dirname(local.terragrunt_dir))

  # ---------------------------------------------------------------------------
  # ENVIRONMENT CONFIG
  # ---------------------------------------------------------------------------
  # Load provider-specific configuration if it exists

  env_config_path = "${get_terragrunt_dir()}/../env.yaml"
  env_config      = fileexists(local.env_config_path) ? yamldecode(file(local.env_config_path)) : {}

  # Global defaults
  default_datacenter = "dc1"
  default_node_class = "cloud"

  # ---------------------------------------------------------------------------
  # WIREGUARD CONFIGURATION
  # ---------------------------------------------------------------------------
  # These should be overridden per-node or via environment variables

  wireguard_subnet            = "10.200.0.0/24"
  wireguard_server_public_key = get_env("MUNCHBOX_WG_SERVER_PUBKEY", "")
  wireguard_endpoint          = get_env("MUNCHBOX_WG_ENDPOINT", "home.example.com:51820")

  # ---------------------------------------------------------------------------
  # CLUSTER CONFIGURATION
  # ---------------------------------------------------------------------------

  consul_servers = ["10.200.0.1"]
  nomad_servers  = ["10.200.0.1:4647"]

  # ---------------------------------------------------------------------------
  # NETWORK CIDRS (Munchbox Convention)
  # ---------------------------------------------------------------------------

  network_cidrs = {
    homelab   = "192.168.68.0/24"
    wireguard = "10.200.0.0/24"
    oci       = "10.100.0.0/16"
    aws       = "10.101.0.0/16"
  }

  # ---------------------------------------------------------------------------
  # SSH CONFIGURATION
  # ---------------------------------------------------------------------------

  ssh_public_key = get_env("MUNCHBOX_SSH_PUBKEY", file("~/.ssh/id_ed25519.pub"))

  # ---------------------------------------------------------------------------
  # PROVIDER-SPECIFIC DEFAULTS
  # ---------------------------------------------------------------------------

  aws_defaults = {
    availability_zones = ["us-east-1a"]
    architecture       = "arm64"
    spot_type          = "persistent"
  }

  oci_defaults = {
    compartment_id = get_env("OCI_COMPARTMENT_ID", "")
  }

  proxmox_defaults = {
    target_node    = "pve"
    disk_storage   = "local-lvm"
    network_bridge = "vmbr0"
    template_name  = "debian-base"
  }

  # ---------------------------------------------------------------------------
  # PROXMOX VMS (On-Prem Cluster)
  # ---------------------------------------------------------------------------
  # These are managed via Ansible post-provision, no cloud-init bootstrap

  proxmox_vms = {
    "nomad-server-03" = {
      target_node = "fontana"
      vmid        = 172
      memory      = 2048
      cores       = 2
      disk_size   = "40G"
      existing    = true
    }

    "nomad-client-01" = {
      target_node = "fontana"
      vmid        = 180
      memory      = 13312
      cores       = 4
      disk_size   = "60G"
      existing    = true
    }

    "nomad-client-02" = {
      target_node = "mccoy"
      vmid        = 181
      memory      = 15360
      cores       = 4
      disk_size   = "40G"
      existing    = true
    }

    "nomad-client-03" = {
      target_node = "cabot"
      vmid        = 182
      memory      = 7168
      cores       = 4
      disk_size   = "40G"
      existing    = true
    }

    "nomad-client-04" = {
      target_node     = "rubirosa"
      vmid            = 183
      memory          = 28672
      cores           = 10
      disk_size       = "40G"
      gpu_passthrough = { pci_address = "02:00" }
    }

    "nomad-client-05" = {
      target_node = "rubirosa"
      vmid        = 184
      memory      = 28672
      cores       = 10
      disk_size   = "40G"
    }
  }

  # ---------------------------------------------------------------------------
  # BOOTSTRAP MODULE INPUTS
  # ---------------------------------------------------------------------------
  # These get merged with node-specific config in the env_helper

  bootstrap_inputs = {
    datacenter     = local.default_datacenter
    node_class     = local.default_node_class
    ssh_public_key = local.ssh_public_key

    wireguard_subnet            = local.wireguard_subnet
    wireguard_server_public_key = local.wireguard_server_public_key
    wireguard_endpoint          = local.wireguard_endpoint
    wireguard_allowed_ips       = "${local.network_cidrs.wireguard}, ${local.network_cidrs.homelab}"

    consul_servers = local.consul_servers
    nomad_servers  = local.nomad_servers

    # Software versions
    consul_version = "1.17.0"
    nomad_version  = "1.7.0"

    # Docker
    allow_privileged_docker = false
    docker_user             = "ubuntu"

    tags = {
      Project   = "munchbox"
      ManagedBy = "terragrunt"
    }
  }
}

# -----------------------------------------------------------------------------
# TERRAFORM CONFIGURATION
# -----------------------------------------------------------------------------

terraform_binary = "terraform"

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}

# -----------------------------------------------------------------------------
# REMOTE STATE
# -----------------------------------------------------------------------------

remote_state {
  backend = "consul"

  config = {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/munchbox/${local.provider_type}/${local.node_name}"
    lock    = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# PROVIDER GENERATION
# -----------------------------------------------------------------------------

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
        oci = {
          source  = "oracle/oci"
          version = "~> 5.0"
        }
        proxmox = {
          source  = "telmate/proxmox"
          version = "3.0.2-rc05"
        }
      }
    }

    provider "aws" {
      region = "us-east-1"

      default_tags {
        tags = {
          Project   = "munchbox"
          ManagedBy = "terragrunt"
        }
      }
    }

    provider "oci" {
      # Uses OCI config file (~/.oci/config) or environment variables
    }

    provider "proxmox" {
      # Uses PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET env vars
      pm_tls_insecure = true
    }
  EOF
}
