# Munchbox Coding Style Guide

**Project:** Munchbox Infrastructure  
**Author:** Alex Freidah

---

## Table of Contents

- [Core Principles](#core-principles)
- [Comment Types and Spacing](#comment-types-and-spacing)
- [File Headers](#file-headers)
- [Nomad Job Structure](#nomad-job-structure)
- [Terragrunt Structure](#terragrunt-structure)
- [Terraform Modules](#terraform-modules)
- [Code Style](#code-style)

---

## Core Principles

- **ASCII-only characters** - Never use Unicode em-dashes, en-dashes, or box-drawing characters
- **Dashes, not equals** - Always use `-` for dividers, never `=`
- **Box comment spacing** - ALL box comments (79-char file headers and 73-char sections) ALWAYS have a blank line after
- **Professional tone** - No personal references, no numbered lists, no casual language
- **2-space indentation** - For HCL/Nomad files
- **Infrastructure as code** - Everything automated, reproducible, no manual steps
- **Self-documenting** - Code explains *why*, not just *what*

---

## Comment Types and Spacing

### 1. File Header (79 characters)

**Format:**
```hcl
# -------------------------------------------------------------------------------
# Title of File or Component
#
# Project: Munchbox / Author: Alex Freidah
#
# 2-4 sentence description of the file's purpose, scope, and key functionality.
# Include architecture notes, design decisions, or important context that helps
# readers understand the overall purpose.
# -------------------------------------------------------------------------------
```

**Spacing Rules:**
- Blank line after title
- Blank line after metadata
- Blank line before closing divider
- **Blank line after closing divider** - always separate box from code

**Example:**
```hcl
# -------------------------------------------------------------------------------
# Prometheus — Metrics Collection and Monitoring
#
# Project: Munchbox / Author: Alex Freidah
#
# Prometheus server with transparent proxy disabled for direct network access
# to Nomad and Consul APIs. Collects metrics from infrastructure services and
# exposes them for Grafana visualization.
# -------------------------------------------------------------------------------

job "prometheus" {
  type = "service"
```

---

### 2. Major Section Box (73 characters)

**Format:**
```hcl
# -------------------------------------------------------------------------
# SECTION NAME
# -------------------------------------------------------------------------

code_block {
  # ...
}
```

**Spacing Rules:**
- Use ALL CAPS for section name
- **Blank line AFTER closing divider** - separates section from code
- Used for major logical divisions

**Example:**
```hcl
# -------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -------------------------------------------------------------------------

network {
  mode = "bridge"
  port "http" { to = 80 }
}
```

---

### 3. Single-Line Section Marker

**Format:**
```hcl
# --- Description of what follows ---
code_block {
  # ...
}
```

**Spacing Rules:**
- **NO blank line before code** - placed directly above the block it describes
- Use lowercase or title case (not ALL CAPS)
- Used for minor divisions or labels

**Example:**
```hcl
# --- Core job configuration ---
job_name = "prometheus"
job_type = "service"

# --- Deployment and metadata ---
deployment_profile = "standard"
meta_profile       = "tier2"
```

---

### 4. Inline Comments

**Format:**
```hcl
config_option = "value"  # Brief explanation if needed
```

**Spacing Rules:**
- Use sparingly
- Explain *why*, not *what*
- Keep concise (< 50 characters)

**Example:**
```hcl
transparent_proxy {}  # Disabled for direct API access
egress_rules = []     # RDS doesn't need outbound
```

---

## Comment Type Decision Tree

```
Is this a file header?
  YES → Use 79-char divider, blank line AFTER
  
Is this a major section (network, storage, constraints)?
  YES → Use 73-char box, blank line AFTER
  
Is this a minor division or label?
  YES → Use single-line marker, NO blank line before code
  
Is this explaining a specific line?
  YES → Use inline comment
```

**Key Rule:** ALL box comments (79-char and 73-char) have a blank line after. Only single-line markers have no spacing.

---

## File Headers

### Nomad Jobs

```hcl
# -------------------------------------------------------------------------------
# Service Name — Brief Description
#
# Project: Munchbox / Author: Alex Freidah
#
# Description of what this service does, its role in the infrastructure, and
# any important architectural decisions. Include deployment characteristics and
# dependencies if relevant to understanding the service.
# -------------------------------------------------------------------------------
```

### Terraform Files

```hcl
# -------------------------------------------------------------------------------
# Module or Resource Description
#
# Project: Munchbox / Author: Alex Freidah
#
# Description of what this Terraform configuration manages. Include provider
# details, resource relationships, and any important state considerations.
# -------------------------------------------------------------------------------
```

### Ansible Playbooks

```yaml
# -------------------------------------------------------------------------------
# Playbook or Role Name
#
# Project: Munchbox / Author: Alex Freidah
#
# Description of what this playbook/role configures. Include target hosts,
# prerequisites, and any important operational considerations.
# -------------------------------------------------------------------------------
```

### Shell Scripts

```bash
#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Script Name
#
# Project: Munchbox / Author: Alex Freidah
#
# Description of what this script does. Include usage instructions, required
# environment variables, and any important caveats or dependencies.
# -------------------------------------------------------------------------------
```

### Go Files

```go
// -------------------------------------------------------------------------------
// Package or File Name
//
// Project: Munchbox / Author: Alex Freidah
//
// Description of what this file or package does. Include key types, functions,
// and any important architectural decisions or dependencies.
// -------------------------------------------------------------------------------
package main
```

**Go-Specific Rules:**
- Use `//` comments (not `/* */` blocks)
- File headers use 79-char dividers with `//`
- Major sections use 73-char dividers with `//`
- Single-line markers: `// --- description ---`
- Standard Go doc comments for exported types/functions (placed directly above)
- 1 tab indentation (Go standard)

**Major Section Example:**
```go
// -------------------------------------------------------------------------
// HTTP HANDLERS
// -------------------------------------------------------------------------

func (s *Server) handlePut(ctx context.Context, w http.ResponseWriter) {
    // ...
}
```

**Single-Line Marker Example:**
```go
// --- Parse request path ---
bucket, key, ok := parsePath(r.URL.Path)
if !ok {
    return errInvalidPath
}
```

---

## Nomad Job Structure

### Structural Order

**Job level:**
- Metadata (name, type, datacenters, namespace)
- Update policy
- Constraints

**Group level:**
- Count
- Network
- Constraints
- Storage (volumes)
- Restart policy
- Reschedule policy

**Task level:**
- Driver
- Identity
- Config
- Service
- Environment
- Resources
- Termination (kill_timeout, kill_signal)

### Example Structure

```hcl
# -------------------------------------------------------------------------------
# Example Service
#
# Project: Munchbox / Author: Alex Freidah
#
# Brief description of what this service does in the infrastructure.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
job_name        = "example"
job_type        = "service"
region          = "global"
datacenters     = ["dc1"]

# --- Update policy ---
update_max_parallel = 1
update_auto_revert  = true

# -------------------------------------------------------------------------
# SERVICE GROUP
# -------------------------------------------------------------------------

group "web" {
  count = 2
  
  # --- Network configuration ---
  network {
    mode = "bridge"
    port "http" { to = 80 }
  }
  
  # --- Storage ---
  volume "data" {
    type   = "host"
    source = "web-data"
  }
  
  # --- Restart policy ---
  restart {
    attempts = 3
    delay    = "30s"
  }
  
  task "server" {
    driver = "docker"
    
    # --- Identity ---
    identity {
      env  = true
      file = false
    }
    
    # --- Container configuration ---
    config {
      image = "nginx:alpine"
      ports = ["http"]
    }
    
    # --- Resources ---
    resources {
      cpu    = 100
      memory = 128
    }
  }
}
```

---

## Terragrunt Structure

Terragrunt provides a DRY wrapper around Terraform modules. Configuration splits across three layers.

### Directory Layout

```
infrastructure/terragrunt/
├── root.hcl                      # Central config, providers, inputs, hooks
├── _env_helpers/                 # Module inclusion, dependencies, logic
│   └── <module-name>.hcl
├── global/                       # Provider-agnostic services
│   └── <service>/terragrunt.hcl
└── <provider>/                   # Provider-specific deployments
    └── <node-name>/
        ├── terragrunt.hcl
        └── node.yaml             # Optional per-instance config
```

### Layer 1: root.hcl

Central configuration file with several key sections:

**locals{}** - Internal configuration, computed values, environment-specific settings:

```hcl
locals {
  # Path parsing - derive context from directory structure
  terragrunt_dir = get_original_terragrunt_dir()
  node_name      = basename(local.terragrunt_dir)
  provider_type  = basename(dirname(local.terragrunt_dir))

  # Environment-specific configuration
  env_config = {
    production = { instance_type = "t3.large", replica_count = 3 }
    staging    = { instance_type = "t3.medium", replica_count = 2 }
  }

  # Computed configuration objects
  networking_config = {
    vpc_cidr = local.env_config[local.environment].vpc_cidr
    # ...
  }
}
```

**inputs{}** - Exposes locals to _env_helpers (accessed via `local.root.inputs.*`):

```hcl
inputs = {
  # Core identity
  environment = local.environment
  region      = local.region
  component   = local.component

  # Configuration objects (single line references to locals)
  networking_config = local.networking_config
  aurora_config     = local.aurora_config
  eks_config        = local.eks_config

  # Common tags
  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
```

**terraform{}** - Extra arguments and hooks for pre/post execution:

```hcl
terraform {
  # Add CLI flags to terraform commands
  extra_arguments "force_named_plan_out" {
    commands  = ["plan"]
    arguments = ["-out=plan.tfplan"]
  }

  # Run security scans after plan/apply
  after_hook "trivy_scan" {
    commands = ["plan", "apply"]
    execute  = ["bash", "-c", "trivy config ."]
  }

  after_hook "checkov_scan" {
    commands = ["plan", "apply"]
    execute  = ["bash", "-c", "checkov -d . -o github_failed_only"]
  }

  # Run tests before apply
  before_hook "validate" {
    commands = ["apply"]
    execute  = ["terraform", "validate"]
  }
}
```

**remote_state{}** - Backend configuration:

```hcl
remote_state {
  backend = "consul"
  config = {
    address = "consul.service.consul:8500"
    path    = "terraform/munchbox/${local.provider_type}/${local.node_name}"
    lock    = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
```

**generate{}** - Generate provider configuration:

```hcl
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        aws = { source = "hashicorp/aws", version = "~> 5.0" }
      }
    }
    provider "aws" {
      region = "${local.region}"
    }
  EOF
}
```

### Layer 2: _env_helpers/<module>.hcl

The env_helper does the real work: includes the module, defines dependencies, computes values, and wires inputs. Access root values via `local.root.inputs.*`.

**Simple helper** - direct pass-through:

```hcl
terraform {
  source = "${get_repo_root()}/modules//<module-name>"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  token       = local.root.inputs.some_token
  vault_mount = local.root.inputs.vault_mount
}
```

**Complex helper** - dependencies, computed values, conditional logic:

```hcl
terraform {
  source = "${get_repo_root()}/modules//<module-name>"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # Load per-instance config
  node_config = yamldecode(file("${get_terragrunt_dir()}/node.yaml"))

  # Conditional provider-specific config
  aws_config = local.root.inputs.provider_type == "aws" ? merge(
    local.root.inputs.aws_defaults,
    try(local.node_config.aws_config, {})
  ) : null
}

# Cross-module dependencies
dependency "networking" {
  config_path = "../general-networking"
  mock_outputs = { vpc_id = "vpc-mock", subnet_ids = ["subnet-mock"] }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = merge(
  {
    environment = local.root.inputs.environment
    region      = local.root.inputs.region
  },
  {
    # Computed identifiers
    cluster_name = "${local.root.inputs.environment}-${local.root.inputs.region}-cluster"

    # Values from dependencies
    vpc_id     = dependency.networking.outputs.vpc_id
    subnet_ids = dependency.networking.outputs.subnet_ids

    # Conditional logic
    role_arn = local.root.inputs.monitoring_interval > 0 ? "arn:..." : null

    # Dynamic env vars
    key = get_env("KEY_${upper(replace(local.root.inputs.node_name, "-", "_"))}", "")

    # Fallbacks with try()
    instance_type = try(local.node_config.instance_type, "t3.medium")

    # Merged tags
    tags = merge(local.root.inputs.common_tags, try(local.node_config.tags, {}))
  }
)
```

### Layer 3: Environment terragrunt.hcl

Minimal - just two includes. All logic lives in env_helper.

```hcl
# -----------------------------------------------------------------------------
# <Service Name>
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "<module>" {
  path   = "${get_repo_root()}/_env_helpers/<module>.hcl"
  expose = true
}
```

---

## Terraform Modules

Modules live in `modules/` and are consumed via Terragrunt.

### Directory Structure

```
modules/<module-name>/
├── main.tf           # Resources (or split by category)
├── variables.tf      # Inputs with validations
├── outputs.tf        # Outputs grouped by category
└── tests/
    └── default.tftest.hcl
```

No `versions.tf` - Terragrunt generates providers.

### main.tf

Comprehensive header with architecture, security model, and warnings:

```hcl
# -----------------------------------------------------------------------------
# <MODULE NAME>
# -----------------------------------------------------------------------------
#
# Brief description.
#
# Components Created:
#   - Resource A: Description
#   - Resource B: Description
#
# Architecture:
#   - How components interact
#   - Design decisions and trade-offs
#
# Security Model:
#   - Access control approach
#   - Network isolation
#
# IMPORTANT:
#   - Destructive operation warnings
#   - Required permissions
#   - Cost considerations
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# <RESOURCE SECTION>
# -----------------------------------------------------------------------------

# Comment explaining WHY this resource exists
resource "provider_resource" "name" {
  count = length(var.availability_zones)

  attribute = var.some_input

  tags = merge(var.tags, { Name = "${var.name}-suffix" })
}
```

### variables.tf

Grouped with categories and validations:

```hcl
# -----------------------------------------------------------------------------
# <MODULE NAME> - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# Variable Categories:
#   - Core: Primary configuration
#   - Network: Subnet and AZ settings
#   - Options: Feature toggles
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CORE CONFIGURATION
# -----------------------------------------------------------------------------

variable "name" {
  description = "Resource name prefix"
  type        = string

  validation {
    condition     = length(var.name) <= 32
    error_message = "Name must be 32 characters or less."
  }
}
```

### outputs.tf

Grouped with usage context:

```hcl
# -----------------------------------------------------------------------------
# <MODULE NAME> - OUTPUT VALUES
# -----------------------------------------------------------------------------
#
# Output Categories:
#   - Identifiers: Resource IDs and ARNs
#   - Network: Subnet and routing info
#
# Usage:
#   - vpc_id: Required for security groups
#   - subnet_ids: For compute placement
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IDENTIFIERS
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
```

### tests/default.tftest.hcl

Test logic, computed values, edge cases - not variable pass-through:

```hcl
# -----------------------------------------------------------------------------
# <MODULE NAME> - TEST SUITE
# -----------------------------------------------------------------------------
#
# Test Categories:
#   - Baseline: Core resource creation
#   - Outputs: Value correctness
#   - Edge Cases: Optional features
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# TEST DEFAULTS
# -----------------------------------------------------------------------------

variables {
  name               = "test"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# -----------------------------------------------------------------------------
# BASELINE
# -----------------------------------------------------------------------------

run "baseline" {
  command = plan

  assert {
    condition     = length(aws_subnet.main) == length(var.availability_zones)
    error_message = "Should create one subnet per AZ"
  }
}
```

**Test focus:** Resource counts, computed values, output structure, edge cases.

**Do NOT test:** Variable pass-through.

---

## Code Style

### Character Rules

**ALWAYS USE:**
- ASCII dash: `-` (hyphen-minus, U+002D)
- Standard ASCII characters only

**NEVER USE:**
- Unicode em-dash: `—` (U+2014)
- Unicode en-dash: `–` (U+2013)
- Unicode box-drawing: `─` (U+2500)
- Equals signs for dividers: `=`

### Indentation

- **2 spaces** for HCL/Nomad files
- **No tabs** - spaces only
- **Consistent alignment** - align similar blocks

### Professional Tone

❌ **Avoid:**
- Personal references: "Let me show you...", "We need to..."
- Numbered lists in comments: "1. First do this", "2. Then do that"
- Conversational tone: "Now we're going to..."
- Future tense: "This will create...", "We'll configure..."

✅ **Use:**
- Present tense: "Creates", "Configures", "Manages"
- Declarative statements: "Service runs on port 8080"
- Technical precision: "Uses transparent proxy for mesh integration"
- Impersonal voice: "The service monitors...", "Configuration defines..."

---

## Quick Reference

| Comment Type | Length | Spacing After | Use Case |
|-------------|--------|---------------|----------|
| File header | 79 chars | 1 blank line | Top of every file |
| Major section | 73 chars | 1 blank line | Major divisions |
| Single-line marker | Variable | None | Minor divisions |
| Inline | Brief | N/A | Specific line explanation |

---

## Examples

### Good

```hcl
# -------------------------------------------------------------------------------
# Traefik — HTTP Reverse Proxy and Load Balancer
#
# Project: Munchbox / Author: Alex Freidah
#
# Traefik handles all HTTP/HTTPS ingress for the cluster, providing automatic
# service discovery via Consul, TLS termination, and routing based on host
# headers. Runs on all client nodes for high availability.
# -------------------------------------------------------------------------------

job "traefik" {
  type = "system"
  
  # -------------------------------------------------------------------------
  # PROXY GROUP
  # -------------------------------------------------------------------------
  
  group "traefik" {
    # --- Network configuration ---
    network {
      mode = "host"
      port "http"  { static = 80 }
      port "https" { static = 443 }
    }
    
    # --- Storage ---
    volume "certs" {
      type   = "host"
      source = "traefik-certs"
    }
  }
}
```

### Bad

```hcl
# ===================================
# Traefik Service
# 
# We're going to configure Traefik for the cluster.
# 
# Steps:
# 1. First we set up the network ports
# 2. Then we configure TLS
# 3. Finally we enable service discovery
# ===================================

job "traefik" {
  
  # Now let's configure the network
  
  network {
    # Port 80 for HTTP
    port "http" { static = 80 }
    
    # Port 443 for HTTPS  
    port "https" { static = 443 }
  }
}
```

---

**Remember:** Comments should explain *why* decisions were made, not *what* the code does. The code itself should be clear enough to understand *what* it does.