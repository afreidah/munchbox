# Bootstrap Module

**One module to deploy a fully configured Munchbox cluster node on any provider.**

Combines `network` + `compute` + cloud-init to provision a node that automatically:
- Connects via WireGuard to your homelab
- Joins your Nomad cluster as a client
- Joins your Consul cluster
- Installs Docker for container workloads

## Quick Start

```hcl
module "cloud_node" {
  source = "../modules/bootstrap"

  # Provider
  provider_type = "aws"
  name          = "nomad-client-aws-1"

  # Compute
  cpu       = 2
  memory_gb = 4
  disk_gb   = 20

  # SSH
  ssh_public_key = var.ssh_public_key

  # WireGuard (connect back to homelab)
  wireguard_private_key       = var.wg_private_key
  wireguard_address           = "10.200.0.10"
  wireguard_server_public_key = var.wg_server_public_key
  wireguard_endpoint          = "home.example.com:51820"

  # Cluster
  consul_servers = ["10.200.0.1"]
  nomad_servers  = ["10.200.0.1:4647"]

  # AWS-specific
  aws_config = {
    availability_zones = ["us-east-1a"]
  }
}

output "ssh" {
  value = module.cloud_node.ssh_connection_string
}

output "wireguard_ip" {
  value = module.cloud_node.wireguard_ip
}
```

## Multi-Provider Example

```hcl
locals {
  nodes = {
    "aws-node-1" = {
      provider = "aws"
      wg_ip    = "10.200.0.10"
      cpu      = 2
      memory   = 4
    }
    "oci-node-1" = {
      provider = "oci"
      wg_ip    = "10.200.0.11"
      cpu      = 2
      memory   = 12
    }
  }
}

module "nodes" {
  source   = "../modules/bootstrap"
  for_each = local.nodes

  provider_type = each.value.provider
  name          = each.key
  cpu           = each.value.cpu
  memory_gb     = each.value.memory
  disk_gb       = 20

  ssh_public_key              = var.ssh_public_key
  wireguard_private_key       = var.wg_keys[each.key].private
  wireguard_address           = each.value.wg_ip
  wireguard_server_public_key = var.wg_server_public_key
  wireguard_endpoint          = "home.example.com:51820"

  consul_servers = ["10.200.0.1"]
  nomad_servers  = ["10.200.0.1:4647"]

  aws_config = each.value.provider == "aws" ? {
    availability_zones = ["us-east-1a"]
  } : null

  oci_config = each.value.provider == "oci" ? {
    compartment_id      = var.oci_compartment_id
    availability_domain = var.oci_ad
  } : null
}
```

## What Gets Installed

The cloud-init script installs and configures:

| Component | Description |
|-----------|-------------|
| **WireGuard** | VPN tunnel back to homelab |
| **Consul** | Service discovery (client mode) |
| **Nomad** | Workload orchestration (client mode) |
| **Docker** | Container runtime for Nomad jobs |

## Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                        HOMELAB                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                     │
│  │ Nomad   │  │ Consul  │  │WireGuard│◄─────┐              │
│  │ Server  │  │ Server  │  │ Server  │      │              │
│  └────┬────┘  └────┬────┘  └────┬────┘      │              │
│       │            │            │           │              │
│       └────────────┴────────────┘           │              │
│                    │                        │              │
│            192.168.68.0/24                  │              │
│                    │                        │              │
│            10.200.0.1 (wg0)                 │              │
└────────────────────┼────────────────────────┼──────────────┘
                     │                        │
                     │    WireGuard Tunnel    │
                     │                        │
┌────────────────────┼────────────────────────┼──────────────┐
│                    │                        │     CLOUD    │
│            10.200.0.10 (wg0)        10.200.0.11 (wg0)      │
│                    │                        │              │
│  ┌─────────────────┴───┐    ┌──────────────┴────┐         │
│  │   AWS Spot Node     │    │   OCI Free Node   │         │
│  │   (Nomad Client)    │    │   (Nomad Client)  │         │
│  └─────────────────────┘    └───────────────────┘         │
└───────────────────────────────────────────────────────────┘
```

## Variables Reference

### Required

| Variable | Description |
|----------|-------------|
| `provider_type` | `"aws"`, `"oci"`, or `"proxmox"` |
| `name` | Node name |
| `ssh_public_key` | SSH key for access |
| `wireguard_private_key` | WG private key for this node |
| `wireguard_address` | WG IP for this node (e.g., `10.200.0.10`) |
| `wireguard_server_public_key` | WG public key of homelab server |
| `wireguard_endpoint` | Homelab WG endpoint (e.g., `home.example.com:51820`) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `cpu` | 2 | CPU cores |
| `memory_gb` | 4 | Memory in GB |
| `disk_gb` | 20 | Disk size in GB |
| `datacenter` | `dc1` | Nomad/Consul datacenter |
| `node_class` | `cloud` | Nomad node class |
| `consul_servers` | `["10.200.0.1"]` | Consul server addresses |
| `nomad_servers` | `["10.200.0.1:4647"]` | Nomad server addresses |
| `create_network` | `true` | Create new VPC/VCN |

## Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Public IP (for initial SSH) |
| `wireguard_ip` | WireGuard IP (for cluster access) |
| `ssh_connection_string` | `ssh ubuntu@<public_ip>` |
| `ssh_via_wireguard` | `ssh ubuntu@<wireguard_ip>` |
| `instance_id` | Provider-specific instance ID |
| `cloud_init_script` | Generated cloud-init (sensitive) |

## Post-Deployment Verification

After the node boots (~2-3 minutes):

```bash
# SSH in (initially via public IP)
ssh ubuntu@<public_ip>

# Check WireGuard
sudo wg show

# Check Consul
consul members

# Check Nomad
nomad node status
```

From your homelab:

```bash
# Node should appear in Nomad
nomad node status

# Node should appear in Consul
consul members
```
