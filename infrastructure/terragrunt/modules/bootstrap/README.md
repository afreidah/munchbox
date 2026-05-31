# Bootstrap Module

**One module to deploy a fully configured Munchbox cluster node on any provider.**

Combines `network` + `compute` + a chef-bootstrap cloud-init that:
- Trusts the munchbox PKI (root + intermediate CA)
- (oracle only) brings up WireGuard wg0 to reach the homelab LAN
- Installs cinc-client directly from `downloads.cinc.sh` (no packagecloud)
- Drops `/etc/cinc/{client.rb, validation.pem, encrypted_data_bag_secret}`
  with values pulled from Vault at terragrunt-apply time
- Runs the first `cinc-client -j /etc/cinc/first_run.json` converge

Everything past first-converge (consul / nomad / docker / vault-agent /
vault-cert-manager / wireguard wg1 / oracle::watchdog / minio mount /
etc.) is owned by chef cookbooks. This module exists only to get a fresh
node to the point where chef takes over.

See [Chef Bootstrap Workflow](#chef-bootstrap-workflow) below for the
full provisioning sequence including the pre-VM steps.

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

---

## Chef Bootstrap Workflow

End-to-end sequence for provisioning a new chef-managed node.

### 0. One-time chef-server prereqs (do this ONCE, not per node)

Vault must hold both the org validator key and the shared
encrypted_data_bag_secret. Default paths the bootstrap module reads:

| Vault path | Field | What |
| --- | --- | --- |
| `secret/cinc/validator-key` | `key` | PEM body of the org's validator (e.g. `munchbox-validator`) |
| `secret/cinc/encrypted_data_bag_secret` | `value` | Shared data-bag secret (already populated when oracle nodes were adopted) |

Override paths via the `chef_validator_vault_*` / `chef_data_bag_secret_vault_*`
variables in the bootstrap module if you store them elsewhere.

To populate the validator key (one-time):

```bash
# If the validator pem was saved on cinc-server at org-create time:
ssh root@cinc-server.munchbox.cc 'cat /etc/cinc-bootstrap/munchbox-validator.pem' \
  | infrastructure/scripts/store-validator-key-in-vault.sh

# OR (DESTRUCTIVE; invalidates any cached copies of the key):
knife client reregister munchbox-validator \
  | infrastructure/scripts/store-validator-key-in-vault.sh
```

### 1. Per-node prereqs (run on workstation BEFORE `terragrunt apply`)

Create the per-node chef node file at
`infrastructure/cinc/nodes/<node>.rb`, then:

```bash
source munchbox-env.sh
infrastructure/scripts/prepare-chef-bootstrap.sh <chef-node-name>
```

This script does three things:

1. Mints a fresh AppRole secret_id from
   `auth/chef-approle/role/chef-managed-node` and stores it at
   `secret/chef-approle/secret-ids/<node>`.
2. Builds + uploads the encrypted `vault_agent/<node>` data-bag item
   to cinc-server (wraps `upload-vault-agent-data-bag.sh`).
3. Uploads the per-node node object (`knife node from file`); the node
   object carries the run_list, tags, and per-node attribute overrides.

### 2. Provision the VM

```bash
cd infrastructure/terragrunt/<provider>/<node>
terragrunt apply
```

Cloud-init runs at first boot and converges chef. Watch progress via
the cloud-init log on the new node:

```bash
ssh <user>@<node> 'sudo tail -f /var/log/cloud-init-output.log'
```

When the bootstrap finishes you'll see `/var/log/munchbox-bootstrap-complete`
appear and the node will register with `knife status`.

### 3. Subsequent converges

The hourly `cinc-client.timer` (installed by `cinc_client::service`) takes
over after first boot. Manual converges via
`ssh <user>@<node> 'sudo cinc-client'` work as normal.

### Per-node terragrunt overrides

Recognized keys in `node.yaml` for the chef bootstrap:

| Key | Default | Notes |
| --- | --- | --- |
| `chef_node_name` | `<node_name>` with hyphens stripped | Match the existing convention (`oraclearm1` not `oracle-arm-1`). |
| `chef_run_list` | `role[<node_name with hyphens→underscores>]` | First-converge role. |
| `bootstrap_wireguard` | `true` unless `provider_type == "proxmox"` | Skip wg0 setup on LAN nodes. |
| `static_ip` | `""` (DHCP) | Set on proxmox VMs that need pinned IPs. |
| `static_netmask_bits` | `24` | CIDR-bits. |
| `gateway` | `""` | Required when `static_ip` is set. |
| `dns_servers` | `[]` | Initial resolvers; `consul::dns` overrides at first converge. |
| `network_interface` | `ens18` | Override per-platform if needed. |
