# Unified Network Module

Multi-cloud/on-prem networking abstraction. Create VPCs/VCNs on **AWS** or **Oracle Cloud**, or reference existing **Proxmox** network bridges.

## Usage

```hcl
# AWS VPC + Security Group
module "aws_network" {
  source = "../modules/network"

  provider_type = "aws"
  name          = "munchbox"
  vpc_cidr      = "10.101.0.0/16"

  # Security presets (applied to security group)
  allow_ssh       = "0.0.0.0/0"
  allow_wireguard = "0.0.0.0/0"
  allow_icmp      = "0.0.0.0/0"
  trusted_cidr    = "10.200.0.0/24"  # WireGuard subnet

  aws_config = {
    availability_zones = ["us-east-1a"]
  }
}

# OCI VCN + Security List
module "oci_network" {
  source = "../modules/network"

  provider_type = "oci"
  name          = "munchbox"
  vpc_cidr      = "10.100.0.0/16"
  subnet_cidr   = "10.100.1.0/24"

  allow_ssh       = "0.0.0.0/0"
  allow_wireguard = "0.0.0.0/0"
  trusted_cidr    = "10.200.0.0/24"

  oci_config = {
    compartment_id = var.compartment_ocid
  }
}

# Proxmox (reference existing bridge)
module "proxmox_network" {
  source = "../modules/network"

  provider_type = "proxmox"
  name          = "munchbox"

  proxmox_config = {
    network_bridge = "vmbr0"
    network_cidr   = "192.168.68.0/24"
  }
}
```

## Combining with Unified Compute

```hcl
module "network" {
  source        = "../modules/network"
  provider_type = "aws"
  name          = "munchbox"
  vpc_cidr      = "10.101.0.0/16"
  allow_ssh     = "0.0.0.0/0"
  trusted_cidr  = "10.200.0.0/24"
  aws_config    = { availability_zones = ["us-east-1a"] }
}

module "node" {
  source        = "../modules/compute"
  provider_type = "aws"
  name          = "nomad-client"
  cpu           = 2
  memory_gb     = 4
  disk_gb       = 20
  ssh_key       = var.ssh_public_key

  aws_config = {
    subnet_id          = module.network.subnet_id
    security_group_ids = [module.network.security_group_id]
  }
}
```

## Universal Interface

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `provider_type` | string | required | `"aws"`, `"oci"`, or `"proxmox"` |
| `name` | string | required | Name prefix for resources |
| `vpc_cidr` | string | `10.0.0.0/16` | VPC/VCN CIDR block |
| `subnet_cidr` | string | `10.0.1.0/24` | Subnet CIDR (OCI only) |
| `allow_ssh` | string | null | Allow SSH from CIDR |
| `allow_wireguard` | string | null | Allow WireGuard from CIDR |
| `allow_icmp` | string | null | Allow ICMP from CIDR |
| `trusted_cidr` | string | null | Allow all TCP/UDP from CIDR |

## Normalized Outputs

Same outputs regardless of provider:

```hcl
module.network.network_id        # VPC ID / VCN ID / bridge name
module.network.subnet_id         # Primary subnet ID
module.network.subnet_ids        # All subnet IDs
module.network.security_group_id # Security group/list ID
module.network.vpc_cidr          # VPC/VCN CIDR
module.network.subnet_cidr       # Subnet CIDR
```

## Provider Notes

### AWS
- Creates VPC, Internet Gateway, public subnet(s), route table
- Subnet CIDRs auto-calculated using `cidrsubnet()`
- Security group with preset rules

### OCI
- Creates VCN, Internet Gateway, public subnet, route table
- Security list with preset rules
- Requires explicit `subnet_cidr`

### Proxmox
- References existing network bridge (no creation)
- Returns bridge name and CIDR for consistency
- No security group (uses host-level firewall)
