# Munchbox Terragrunt

Terragrunt wrapper for deploying Munchbox cluster nodes across AWS, OCI, and Proxmox.

## Structure

```
terragrunt/
├── root.hcl                    # Centralized config (WireGuard, cluster, defaults)
├── _env_helpers/
│   └── bootstrap.hcl           # Bootstrap module logic
├── aws/
│   └── nomad-client-aws-1/
│       ├── node.yaml           # Node-specific config
│       └── terragrunt.hcl      # Just includes root + bootstrap
├── oci/
│   └── nomad-client-oci-1/
│       ├── node.yaml
│       └── terragrunt.hcl
└── proxmox/
    └── nomad-client-pve-1/
        ├── node.yaml
        └── terragrunt.hcl
```

## Quick Start

### 1. Set Environment Variables

```bash
# WireGuard server config
export MUNCHBOX_WG_SERVER_PUBKEY="your-server-public-key"
export MUNCHBOX_WG_ENDPOINT="home.example.com:51820"

# Per-node WireGuard private keys (named by node)
export WG_PRIVATE_KEY_NOMAD_CLIENT_AWS_1="node-private-key"

# Provider credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export OCI_COMPARTMENT_ID="ocid1.compartment..."
```

### 2. Deploy a Node

```bash
cd terragrunt/aws/nomad-client-aws-1
terragrunt init
terragrunt plan
terragrunt apply
```

### 3. Deploy All Nodes

```bash
cd terragrunt
terragrunt run-all apply
```

## Adding a New Node

1. Create directory: `<provider>/<node-name>/`
2. Create `node.yaml` with node config
3. Create `terragrunt.hcl` that includes root + bootstrap

Example `node.yaml`:
```yaml
name: nomad-client-aws-2
cpu: 2
memory_gb: 4
disk_gb: 20
wireguard_address: "10.200.0.13"

aws_config:
  availability_zones:
    - us-east-1a
  architecture: arm64
```

Example `terragrunt.hcl`:
```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "bootstrap" {
  path = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/bootstrap.hcl"
}
```

## Configuration Reference

### root.hcl

Centralized config including:
- WireGuard subnet and server details
- Consul/Nomad server addresses
- Network CIDRs by provider
- Default software versions
- Provider-specific defaults

### node.yaml

Per-node config:
| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Node name (defaults to directory name) |
| `cpu` | No | CPU cores (default: 2) |
| `memory_gb` | No | Memory in GB (default: 4) |
| `disk_gb` | No | Disk size in GB (default: 20) |
| `wireguard_address` | Yes | WireGuard IP for this node |
| `node_class` | No | Nomad node class (default: cloud) |
| `aws_config` | If AWS | AWS-specific settings |
| `oci_config` | If OCI | OCI-specific settings |
| `proxmox_config` | If Proxmox | Proxmox-specific settings |

## State Management

State is stored in Consul at:
```
terraform/munchbox/<provider>/<node-name>
```

Each node has isolated state - you can destroy one without affecting others.
