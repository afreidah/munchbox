# Munchbox Coding Style Guide

**Project:** Munchbox Infrastructure  
**Author:** Alex Freidah

---

## Table of Contents

- [Core Principles](#core-principles)
- [Comment Types and Spacing](#comment-types-and-spacing)
- [File Headers](#file-headers)
- [Nomad Job Structure](#nomad-job-structure)
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