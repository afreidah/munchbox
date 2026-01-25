# Munchbox Terragrunt

Terragrunt wrapper for deploying Munchbox infrastructure across OCI and Proxmox.

## Structure

```
terragrunt/
├── root.hcl                    # Centralized config (WireGuard, cluster, defaults)
├── _env_helpers/               # Module inclusion and dependency logic
│   ├── bootstrap.hcl           # Node bootstrap module
│   ├── proxmox-cluster.hcl     # Proxmox VM cluster
│   ├── kms-oci.hcl             # OCI KMS for Vault auto-unseal
│   ├── consul-acls.hcl         # Consul ACL policies
│   ├── nomad-acls.hcl          # Nomad ACL policies
│   ├── vault-config.hcl        # Vault configuration
│   ├── oauth2-proxy-secrets.hcl
│   ├── vaultwarden-secrets.hcl
│   └── dns.hcl
├── global/                     # Provider-agnostic services
│   ├── consul-acls/
│   ├── nomad-acls/
│   ├── vault-config/
│   ├── dns/
│   ├── oauth2-proxy-secrets/
│   └── vaultwarden-secrets/
├── oci/                        # Oracle Cloud Infrastructure
│   ├── oracle-arm-1/           # ARM node
│   ├── oracle-arm-2/           # ARM node
│   ├── oracle-node-1/          # x86 node
│   ├── oracle-node-2/          # x86 node
│   ├── kms/                    # Vault auto-unseal KMS
│   └── object-storage/
└── proxmox/
    └── cluster/                # Proxmox VM definitions
```

## Quick Start

### 1. Set Environment Variables

```bash
# WireGuard server config
export MUNCHBOX_WG_SERVER_PUBKEY="your-server-public-key"
export MUNCHBOX_WG_ENDPOINT="home.example.com:51820"

# Per-node WireGuard private keys (named by node)
export WG_PRIVATE_KEY_ORACLE_ARM_1="node-private-key"

# Provider credentials
export OCI_COMPARTMENT_ID="ocid1.compartment..."
```

### 2. Deploy a Node

```bash
cd terragrunt/oci/oracle-arm-1
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
3. Create `terragrunt.hcl` that includes root + env_helper

Example `node.yaml`:
```yaml
name: oracle-arm-3
cpu: 2
memory_gb: 12
disk_gb: 50
wireguard_address: "10.200.0.14"

oci_config:
  availability_domain: "AD-1"
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
| `oci_config` | If OCI | OCI-specific settings |
| `proxmox_config` | If Proxmox | Proxmox-specific settings |

## State Management

State is stored in Consul at:
```
terraform/munchbox/<provider>/<node-name>
```

Each node has isolated state - you can destroy one without affecting others.
