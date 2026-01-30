# Unified Compute Module

Multi-cloud/on-prem compute abstraction. Provision instances on **AWS**, **Oracle Cloud**, or **Proxmox** using a single interface.

## Usage

```hcl
# AWS Spot Instance
module "aws_node" {
  source = "../modules/compute"

  provider_type = "aws"
  name          = "nomad-client-aws"
  cpu           = 2
  memory_gb     = 4
  disk_gb       = 20
  ssh_key       = var.ssh_public_key

  aws_config = {
    subnet_id          = module.networking.public_subnet_ids[0]
    security_group_ids = [module.security_group.security_group_id]
    # Optional overrides:
    # instance_type         = "t4g.large"    # Override auto-selection
    # architecture          = "x86_64"       # Default: arm64
    # spot_type             = "one-time"     # Default: persistent
    # interruption_behavior = "terminate"    # Default: stop
    # assign_elastic_ip     = true           # Default: false
  }
}

# Oracle Cloud Instance
module "oci_node" {
  source = "../modules/compute"

  provider_type = "oci"
  name          = "nomad-client-oci"
  cpu           = 2
  memory_gb     = 12
  disk_gb       = 50
  ssh_key       = var.ssh_public_key

  oci_config = {
    compartment_id      = var.compartment_ocid
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    subnet_id           = module.networking.subnet_id
    # Optional:
    # shape = "VM.Standard.E2.1.Micro"  # Override auto-selection
  }
}

# Proxmox VM
module "proxmox_node" {
  source = "../modules/compute"

  provider_type = "proxmox"
  name          = "nomad-client-01"
  cpu           = 4
  memory_gb     = 8
  disk_gb       = 32
  ssh_key       = var.ssh_public_key  # Note: Proxmox uses template's SSH keys

  proxmox_config = {
    target_node = "pve"
    vmid        = 201
    # Optional:
    # template_name  = "debian-base"
    # disk_storage   = "local-lvm"
    # network_bridge = "vmbr0"
    # gpu_passthrough = { pci_address = "0000:01:00" }
  }
}
```

## Universal Interface

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `provider_type` | string | required | `"aws"`, `"oci"`, or `"proxmox"` |
| `name` | string | required | Instance/VM name |
| `cpu` | number | 2 | CPU cores/vCPUs/OCPUs |
| `memory_gb` | number | 4 | Memory in GB |
| `disk_gb` | number | 20 | Root disk size in GB |
| `ssh_key` | string | required | SSH public key |
| `user_data` | string | null | Cloud-init script |
| `tags` | map(string) | {} | Resource tags |

## Normalized Outputs

Same outputs regardless of provider:

```hcl
output "id"                    # Instance/VM ID
output "public_ip"             # Public IP address
output "private_ip"            # Private IP address
output "ssh_connection_string" # "ssh ubuntu@<ip>"
output "provider_type"         # Which provider was used
output "name"                  # Instance name
```

## Auto-Selection Logic

### AWS Instance Type (based on memory_gb)
- ≤1 GB → `t4g.micro`
- ≤2 GB → `t4g.small`
- ≤4 GB → `t4g.medium`
- ≤8 GB → `t4g.large`
- >8 GB → `t4g.xlarge`

### OCI Shape (based on cpu/memory)
- 1 CPU + ≤1 GB → `VM.Standard.E2.1.Micro` (Always Free)
- Otherwise → `VM.Standard.A1.Flex` (Always Free ARM)

## Provider Requirements

The root module must configure the appropriate provider(s):

```hcl
# For AWS
provider "aws" {
  region = "us-east-1"
}

# For OCI
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  # ...
}

# For Proxmox
provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  # ...
}
```

Only configure the provider(s) you're actually using.
