# Munchbox Infrastructure

This directory contains all infrastructure-as-code for the Munchbox homelab cluster.

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Proxmox Cluster                       │
                    │                                                          │
  ┌─────────┐       │  ┌─────────┐    ┌─────────┐    ┌─────────┐              │
  │ stabler │       │  │  cabot  │    │  mccoy  │    │ fontana │              │
  │  (Pi5)  │       │  │ 8GB RAM │    │ 16GB    │    │ 16GB    │              │
  │ ARM64   │       │  │         │    │ NFS Srv │    │         │              │
  └────┬────┘       │  └────┬────┘    └────┬────┘    └────┬────┘              │
       │            │       │              │              │                    │
       │            │       │              │              │                    │
       │            │  ┌────▼────┐    ┌────▼────┐   ┌────▼────┐ ┌────────────┐│
       │            │  │client-03│    │client-02│   │client-01│ │ server-03  ││
       │            │  │ 7GB RAM │    │ 15GB    │   │ 13GB    │ │ 2GB RAM    ││
       │            │  └─────────┘    └─────────┘   └─────────┘ └────────────┘│
       │            └─────────────────────────────────────────────────────────┘
       │
  ┌────▼────┐
  │  goren  │
  │  (Pi5)  │
  │ ARM64   │
  └─────────┘

  Legend:
    stabler, goren     = Bare-metal Raspberry Pi 5 (Nomad servers)
    nomad-server-03    = VM-based Nomad server (for 3-node quorum)
    nomad-client-01/02/03 = VM-based Nomad clients (workload runners)
```

## Single Source of Truth: nodes.yml

All infrastructure is defined in `nodes.yml`. This file contains:
- Proxmox hypervisor hosts
- Bare-metal nodes (Pi5s)
- Virtual machines (on Proxmox)
- Network configuration

**Never edit Ansible inventory or Terraform vars directly** - they are auto-generated from `nodes.yml`.

## Quick Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make generate` | Regenerate inventory and tfvars from nodes.yml |
| `make show-nodes` | Display current node configuration |
| `make add-vm VM=name` | Add a new VM (full workflow) |
| `make add-node VM=name` | Configure existing node |
| `make tf-plan` | Preview Terraform changes |
| `make tf-apply` | Apply Terraform changes |

## Adding a New VM

1. **Edit `nodes.yml`** - add the VM definition:
   ```yaml
   vms:
     nomad-client-04:
       proxmox_host: thinkstation  # which Proxmox host
       vmid: 183                   # unique VM ID
       ip: 192.168.68.75           # static IP to assign
       cores: 8
       memory_mb: 32768
       disk_gb: 100
       roles:
         - nomad_client
         - consul_client
   ```

2. **Run the workflow**:
   ```bash
   make add-vm VM=nomad-client-04
   ```

   This will:
   - Generate new inventory and tfvars
   - Create the VM in Proxmox
   - Wait for it to boot
   - Install Docker, Consul, Nomad
   - Join it to the cluster

## Adding a New Proxmox Host

1. **Install Proxmox VE** on the physical machine from ISO

2. **Join Proxmox cluster** (if desired):
   ```bash
   pvecm add <existing-node-ip>
   ```

3. **Edit `nodes.yml`** to add the host:
   ```yaml
   proxmox_hosts:
     thinkstation:
       ip: 192.168.68.XX
       ram_gb: 64
       cpu_cores: 24
       storage: local-lvm
       features:
         - gpu_passthrough
   ```

4. **Create VM template** on the new host (clone from existing or create fresh)

5. **Add VMs** using the normal workflow above

## Adding a Bare-Metal Node

1. **Edit `nodes.yml`**:
   ```yaml
   bare_metal:
     new-pi:
       ip: 192.168.68.XX
       arch: arm64
       roles:
         - nomad_client
         - consul_client
   ```

2. **Regenerate and provision**:
   ```bash
   make generate
   make add-node VM=new-pi
   ```

## Directory Structure

```
infrastructure/
├── nodes.yml                    # SINGLE SOURCE OF TRUTH
├── Makefile                     # Workflow commands
├── README.md                    # This file
├── scripts/
│   ├── generate-inventory.py    # Generates Ansible inventory
│   └── generate-tfvars.py       # Generates Terraform vars
├── terraform/
│   ├── proxmox/                 # VM provisioning
│   │   ├── main.tf              # VM resources (for_each)
│   │   ├── variables.tf         # Variable definitions
│   │   └── vms.auto.tfvars      # AUTO-GENERATED
│   ├── consul-acls/             # Consul ACL policies
│   ├── vault-config/            # Vault configuration
│   └── dns/                     # DNS management
└── ansible/
    ├── inventory/
    │   └── hosts.yml            # AUTO-GENERATED
    ├── group_vars/
    │   └── all.yml              # Global variables
    ├── roles/
    │   ├── consul/              # Consul installation
    │   ├── nomad/               # Nomad installation
    │   └── vault/               # Vault installation
    └── playbooks/
        ├── add-node.yml         # Single node provisioning
        ├── site.yml             # Full cluster setup
        └── ...                  # Other playbooks
```

## Network Layout

| IP | Hostname | Type | Role |
|----|----------|------|------|
| 192.168.68.58 | nomad-server-03 | VM | Nomad/Consul Server |
| 192.168.68.59 | cabot | Proxmox | Hypervisor |
| 192.168.68.60 | goren | Pi5 | Nomad/Consul Server |
| 192.168.68.61 | stabler | Pi5 | Nomad/Consul/Vault Server |
| 192.168.68.62 | pihole-1 | VM | DNS |
| 192.168.68.63 | mccoy | Proxmox | Hypervisor + NFS |
| 192.168.68.64 | pihole-2 | VM | DNS |
| 192.168.68.65 | fontana | Proxmox | Hypervisor |
| 192.168.68.67 | nomad-client-01 | VM | Nomad Client |
| 192.168.68.71 | nomad-client-03 | VM | Nomad Client |
| 192.168.68.72 | nomad-client-02 | VM | Nomad Client |

## Troubleshooting

### Terraform state issues after refactoring
If existing VMs aren't recognized after switching to `for_each`:
```bash
# Import existing resources
cd terraform/proxmox
terraform import 'proxmox_vm_qemu.vm["nomad-server-03"]' fontana/qemu/172
terraform import 'proxmox_vm_qemu.vm["nomad-client-01"]' fontana/qemu/180
# etc.
```

### Node won't join cluster
Check that retry_join IPs are correct:
```bash
# On the problem node
consul members
nomad server members
```

### Dynamic variables not working
Make sure you've run `make generate` after editing `nodes.yml`.
