# Nomad ACL Configuration

Terraform configuration for Nomad ACL policies and tokens.

## Prerequisites

1. Nomad ACLs enabled and bootstrapped
2. Bootstrap token stored in Vault at `secret/nomad/bootstrap`
3. Vault accessible with token that can write to `secret/` and `kv/`

## Structure

```
nomad-acl/
├── main.tf                    # Providers
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables (copy to terraform.tfvars)
├── policies/
│   ├── operators.tf           # Human operator policies (admin, developer, read-only)
│   └── services.tf            # Service policies (hashi-ui, backup-worker, prometheus)
└── tokens/
    ├── services.tf            # Service tokens
    └── vault.tf               # Vault secrets for token storage
```

## Policies

| Policy | Description | Use Case |
|--------|-------------|----------|
| `admin` | Full cluster access | Operators |
| `developer` | Job management in default namespace | Developers |
| `read-only` | Monitoring access | Dashboards |
| `hashi-ui` | Read-only for dashboard | Hashi-UI job |
| `backup-worker` | Snapshot access | Temporal backup |
| `prometheus` | Metrics scraping | Prometheus job |

## Usage

```bash
# Initialize
terraform init

# Create tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your tokens

# Plan
terraform plan

# Apply
terraform apply
```

## Token Storage

Tokens are stored in Vault for retrieval by jobs:

| Service | Vault Path | Template Reference |
|---------|------------|-------------------|
| hashi-ui | `secret/data/hashiuisecret` | `{{ with secret "secret/data/hashiuisecret" }}{{ .Data.data.token }}{{ end }}` |
| backup-worker | `kv/data/backup-worker` | `{{ with secret "kv/data/backup-worker" }}{{ .Data.data.nomad_token }}{{ end }}` |
| prometheus | `kv/data/prometheus-nomad` | `{{ with secret "kv/data/prometheus-nomad" }}{{ .Data.data.nomad_token }}{{ end }}` |

## Job Updates Required

After applying, update these jobs to use the new tokens:

1. **hashi-ui** - Already configured for `secret/data/hashiuisecret`
2. **temporal-backup-worker** - Already configured for `kv/data/backup-worker`
3. **prometheus** - Add authorization header for Nomad scraping (optional)
