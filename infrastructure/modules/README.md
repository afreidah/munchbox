# Munchbox Terraform Modules

Reusable infrastructure modules for multi-cloud and on-prem deployments.

## High-Level Module

| Module | Description |
|--------|-------------|
| **[bootstrap](./bootstrap/)** | **One module to rule them all** - Deploy a fully configured Nomad/Consul node with WireGuard connectivity on any provider |

### Bootstrap Example

```hcl
module "aws_node" {
  source = "../modules/bootstrap"

  provider_type = "aws"
  name          = "nomad-client-aws-1"
  cpu           = 2
  memory_gb     = 4
  ssh_public_key = var.ssh_public_key

  # WireGuard back to homelab
  wireguard_private_key       = var.wg_private_key
  wireguard_address           = "10.200.0.10"
  wireguard_server_public_key = var.wg_server_public_key
  wireguard_endpoint          = "home.example.com:51820"

  # Join cluster
  consul_servers = ["10.200.0.1"]
  nomad_servers  = ["10.200.0.1:4647"]

  aws_config = { availability_zones = ["us-east-1a"] }
}

# Node automatically joins your Nomad cluster!
output "ip" { value = module.aws_node.public_ip }
```

## Unified Modules (Multi-Provider)

These modules provide a single interface across AWS, Oracle Cloud, and Proxmox:

| Module | Description |
|--------|-------------|
| **[compute](./compute/)** | Provision instances: AWS spot, OCI instances, Proxmox VMs |
| **[network](./network/)** | Create networks: AWS VPC, OCI VCN, or reference Proxmox bridges |

### Example: Full Stack on Any Provider

```hcl
locals {
  provider = "aws"  # Change to "oci" or "proxmox" to switch providers
}

module "network" {
  source        = "../modules/network"
  provider_type = local.provider
  name          = "munchbox"
  vpc_cidr      = "10.101.0.0/16"
  allow_ssh     = "0.0.0.0/0"
  trusted_cidr  = "10.200.0.0/24"

  aws_config     = local.provider == "aws" ? { availability_zones = ["us-east-1a"] } : null
  oci_config     = local.provider == "oci" ? { compartment_id = var.compartment_ocid } : null
  proxmox_config = local.provider == "proxmox" ? { network_bridge = "vmbr0" } : null
}

module "node" {
  source        = "../modules/compute"
  provider_type = local.provider
  name          = "nomad-client-1"
  cpu           = 2
  memory_gb     = 4
  disk_gb       = 20
  ssh_key       = var.ssh_public_key

  aws_config = local.provider == "aws" ? {
    subnet_id          = module.network.subnet_id
    security_group_ids = [module.network.security_group_id]
  } : null

  oci_config = local.provider == "oci" ? {
    compartment_id      = var.compartment_ocid
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    subnet_id           = module.network.subnet_id
  } : null

  proxmox_config = local.provider == "proxmox" ? {
    target_node = "pve"
    vmid        = 201
  } : null
}

# Same outputs regardless of provider
output "node_ip" {
  value = module.node.public_ip
}
```

## Provider-Specific Modules

Low-level modules for each provider. Used by unified modules internally, but can be used directly for provider-specific needs:

### AWS
| Module | Description |
|--------|-------------|
| **[networking](./networking/)** | VPC, subnets, IGW, routes |
| **[security-group](./security-group/)** | Security group with presets |
| **[compute-spot](./compute-spot/)** | EC2 spot instances |

### Oracle Cloud
| Module | Description |
|--------|-------------|
| **[networking-oci](./networking-oci/)** | VCN, subnet, IGW, routes |
| **[security-list-oci](./security-list-oci/)** | Security list with presets |
| **[compute-oci](./compute-oci/)** | OCI instances (AMD/ARM) |

### Proxmox
| Module | Description |
|--------|-------------|
| **[compute-proxmox](./compute-proxmox/)** | Proxmox VMs from template |

## Module Architecture

```
                    ┌─────────────────┐
                    │   Your Config   │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
     ┌────────▼────────┐          ┌────────▼────────┐
     │     network     │          │     compute     │
     │    (unified)    │          │    (unified)    │
     └────────┬────────┘          └────────┬────────┘
              │                             │
    ┌─────────┼─────────┐        ┌─────────┼─────────┐
    │         │         │        │         │         │
┌───▼───┐ ┌───▼───┐ ┌───▼───┐ ┌──▼──┐ ┌───▼───┐ ┌───▼────┐
│  AWS  │ │  OCI  │ │Proxmox│ │ AWS │ │  OCI  │ │Proxmox │
│  VPC  │ │  VCN  │ │bridge │ │spot │ │compute│ │   VM   │
└───────┘ └───────┘ └───────┘ └─────┘ └───────┘ └────────┘
```

## Network CIDRs (Munchbox Convention)

| Network | CIDR | Purpose |
|---------|------|---------|
| Homelab (Proxmox) | 192.168.68.0/24 | On-prem network |
| WireGuard | 10.200.0.0/24 | VPN mesh |
| Oracle Cloud | 10.100.0.0/16 | OCI VCN |
| AWS | 10.101.0.0/16 | AWS VPC |

## Common Outputs

All compute modules return:
- `public_ip` - Public IP address
- `private_ip` - Private IP address
- `ssh_connection_string` - Ready-to-use SSH command

All network modules return:
- `network_id` - VPC/VCN/bridge identifier
- `subnet_id` - Primary subnet ID
- `security_group_id` - Security group/list ID
