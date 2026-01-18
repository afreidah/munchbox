<div align="center">

# Homelab Infrastructure Platform - Munchbox Cloud

### Production-Grade Self-Hosted Infrastructure on HashiCorp Stack

[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red.svg)](LICENSE)
[![Nomad](https://img.shields.io/badge/Nomad-v1.10.3-00CA8E?logo=nomad)](https://www.nomadproject.io/)
[![Consul](https://img.shields.io/badge/Consul-v1.21.3-F24C53?logo=consul)](https://www.consul.io/)
[![Vault](https://img.shields.io/badge/OpenBao-v0.2.1-000000?logo=vault)](https://openbao.org/)
[![Traefik](https://img.shields.io/badge/Traefik-v3.5.3-24A1C1?logo=traefikproxy)](https://traefik.io/)
[![Go](https://img.shields.io/badge/Go-1.23+-00ADD8?logo=go)](https://golang.org/)

---

**A complete infrastructure platform featuring workload orchestration, service discovery, secrets management, and comprehensive monitoring—all managed as code.**

[Features](#key-features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Documentation](#documentation)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
  - [Core Stack](#core-stack)
  - [Infrastructure Services](#infrastructure-services)
- [Directory Structure](#directory-structure)
- [Technology Stack](#technology-stack)
- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [Initial Setup](#initial-setup)
  - [Service Access](#service-access)
- [Feature Details](#feature-details)
  - [Automatic Metadata Injection](#automatic-metadata-injection)
  - [Service Tiers](#service-tiers)
  - [Security Scanning](#security-scanning)
  - [Backup Strategy](#backup-strategy)
- [Make Targets Reference](#make-targets-reference)
- [Nomad Job Categories](#nomad-job-categories)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project implements a complete homelab infrastructure using modern DevOps practices and cloud-native technologies. It provides a robust foundation for running containerized workloads, managing secrets, service discovery, and monitoring across a distributed cluster of nodes.

Built on the HashiCorp stack (Nomad, Consul, Vault/OpenBao) and managed entirely through Infrastructure as Code using CDKTF (Terraform CDK) in Go, this platform demonstrates enterprise-grade patterns in a self-hosted environment.

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Infrastructure as Code** | CDKTF (Terraform CDK) in Go for declarative infrastructure management |
| **Security First** | Automated security scanning with Trivy, Checkov, and comprehensive ACL policies |
| **Full Observability** | Prometheus metrics, Grafana dashboards, Loki log aggregation, and Alertmanager notifications |
| **Secrets Management** | Vault/OpenBao with workload identity integration |
| **Service Mesh** | Consul for service discovery and health checking |
| **Workload Orchestration** | Nomad for container and VM workload scheduling |
| **CI/CD** | GitHub Actions pipelines for automated testing and deployment |
| **Configuration Management** | Chef cookbooks for infrastructure provisioning |

---

## 🏗️ Architecture

### Core Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **HashiCorp Nomad** | v1.10.3 | Workload scheduling and deployment |
| **HashiCorp Consul** | v1.21.3 | Service mesh and configuration |
| **OpenBao** | v0.2.1 | Fork of Vault for secrets management |
| **Traefik** | v3.5.3 | Dynamic routing with automatic TLS |
| **Prometheus Stack** | Latest | Metrics collection and alerting |
| **Grafana** | v12.2.0 | Metrics visualization |
| **Loki** | v3.2.0 | Log aggregation |

### Infrastructure Services

- **Edge Access**: Cloudflare Tunnel for secure external access
- **Container Registry**: Private Docker registry mirror with web UI
- **Logging**: Centralized log aggregation with Loki and Promtail
- **Alerting**: Telegram notifications via Alertmanager
- **Backup**: Automated snapshots for Consul and Nomad state

---

## 📁 Directory Structure

```
.
├── .github/workflows/          # CI/CD pipelines
│   ├── cdktf-ci.yml           # Infrastructure deployment pipeline
│   └── docker-ci.yml          # Container build and security scanning
│
├── cdktf/                      # Infrastructure as Code
│   ├── common/                 # Shared Go libraries
│   │   ├── consul.go           # Consul provider utilities
│   │   ├── metadata.go         # Job metadata management
│   │   ├── nomad.go            # Nomad provider utilities
│   │   ├── validation.go       # Metadata validation
│   │   └── vault.go            # Vault provider utilities
│   │
│   ├── cmd/                    # CLI utilities
│   │   ├── nomad-query/        # Query Nomad job metadata
│   │   └── validate-structure/ # Validate job organization
│   │
│   ├── infra/                  # Infrastructure definitions
│   │   ├── cloudflare/         # DNS and CDN configuration
│   │   ├── consul-policy/      # Consul ACL policies
│   │   ├── consul-tokens/      # Consul ACL tokens
│   │   ├── nomad-jobs/         # Nomad job specifications
│   │   │   ├── backup/         # Automated backup jobs
│   │   │   ├── development/    # Dev tools and registry
│   │   │   ├── infrastructure/ # Core services
│   │   │   ├── logging/        # Loki and Promtail
│   │   │   ├── monitoring/     # Prometheus stack
│   │   │   └── utility/        # Helper jobs
│   │   ├── nomad-policy/       # Nomad ACL policies
│   │   ├── vault-policy/       # Vault ACL policies
│   │   └── vault-jwt-roles/    # Vault workload identity roles
│   │
│   ├── Makefile                # Build and deployment automation
│   ├── cdktf.json              # CDKTF configuration
│   └── main.go                 # CDKTF application entry point
│
├── chef/cookbooks/             # Configuration management
│   ├── consul/                 # Consul installation and config
│   │   ├── recipes/            # Chef recipes
│   │   ├── resources/          # Custom resources
│   │   └── templates/          # Configuration templates
│   │
│   ├── nomad/                  # Nomad installation and config
│   │   ├── recipes/            # Chef recipes
│   │   ├── resources/          # Custom resources
│   │   └── templates/          # Configuration templates
│   │
│   └── openbao/                # OpenBao installation and config
│       ├── recipes/            # Chef recipes
│       ├── resources/          # Custom resources
│       └── templates/          # Configuration templates
│
└── docker/                     # Custom Docker images
    ├── Makefile                # Docker build automation
    ├── deluge-vpn/             # VPN-enabled torrent client
    └── ops-build-image/        # CI/CD toolchain image
```

---

## 🛠️ Technology Stack

### Infrastructure Layer

- **IaC**: CDKTF (Terraform CDK) with Go
- **Orchestration**: Nomad, Docker, raw_exec driver
- **Service Discovery**: Consul with DNS integration
- **Secrets**: OpenBao (Vault fork) with workload identity
- **Networking**: CNI plugins, Traefik reverse proxy
- **Configuration**: Chef with custom cookbooks and resources

### Monitoring & Observability

- **Metrics**: Prometheus, Node Exporter, Blackbox Exporter
- **Visualization**: Grafana with pre-configured dashboards
- **Logging**: Loki + Promtail for log aggregation
- **Alerting**: Alertmanager with Telegram integration
- **Health Checks**: Consul health checks + Traefik healthcheck middleware

### Security

- **Scanning**: Trivy (container + config), Checkov (IaC)
- **TLS**: Automated certificate generation and rotation
- **ACLs**: Fine-grained access control across all services
- **Encryption**: Gossip encryption, TLS everywhere
- **Secrets**: Vault workload identity, no hardcoded credentials

### Development Tools

- **CI/CD**: GitHub Actions with self-hosted runners
- **Registry**: Private Docker registry with web UI
- **Testing**: Kitchen (Test Kitchen) for cookbook testing
- **Linting**: golangci-lint, staticcheck, cookstyle

---

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed:

- **Go** 1.23 or later
- **Node.js** 24.x
- **Docker** and Docker Compose
- **Consul**, **Nomad**, and **Vault/OpenBao** CLI tools
- **Chef Workstation** (for configuration management)
- **Make** (for automation)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd homelab-infrastructure
   ```

2. **Bootstrap the cluster**:
   ```bash
   cd cdktf
   make init          # Install dependencies and fetch providers
   make build-all     # Build all binaries
   ```

3. **Validate configuration**:
   ```bash
   make validate      # Validate all Nomad jobs
   make check-structure  # Validate directory structure
   ```

4. **Deploy infrastructure**:
   ```bash
   make synth         # Generate Terraform JSON
   make deploy        # Deploy all infrastructure
   ```

5. **Deploy specific services**:
   ```bash
   # Deploy only monitoring and infrastructure services
   make deploy-jobs JOBS=monitoring,infrastructure
   
   # Deploy all jobs in a specific category
   make deploy-category CAT=monitoring
   ```

### Service Access

Once deployed, services are available at:

| Service | URL | Purpose |
|---------|-----|---------|
| **Nomad UI** | https://nomad.munchbox | Workload management |
| **Consul UI** | https://consul.munchbox | Service discovery |
| **Grafana** | https://grafana.munchbox | Metrics visualization |
| **Prometheus** | https://prometheus.munchbox | Metrics collection |
| **Traefik** | https://traefik.munchbox | Reverse proxy dashboard |
| **Alertmanager** | https://alertmanager.munchbox | Alert management |
| **Loki** | https://loki.munchbox | Log aggregation |
| **Registry UI** | https://registry.munchbox | Docker registry |

> **Note**: All services are LAN-restricted except for the public resume site accessible via Cloudflare Tunnel.

---

## 🔍 Feature Details

### Automatic Metadata Injection

All Nomad jobs receive automatic metadata injection for tracking and management:

```hcl
meta {
  # Version tracking
  version     = "1.0.0"
  image_tag   = "main"
  
  # Ownership
  owner       = "alex.freidah"
  
  # Classification
  category    = "monitoring"
  tier        = "tier-1"
  environment = "production"
  
  # Description
  description = "Prometheus metrics collection"
}
```

Features:
- **Automatic Category Inference**: Derived from directory structure
- **Tier Assignment**: Based on service criticality
- **Git Integration**: Tracks deployment branch
- **Validation**: Ensures all required fields are present

### Service Tiers

Jobs are organized into tiers with automatic assignment based on category:

| Tier | Priority | Use Case | Examples |
|------|----------|----------|----------|
| **Tier 0** | Critical | Infrastructure services | Traefik, Consul agents |
| **Tier 1** | Important | Monitoring and logging | Prometheus, Grafana, Loki |
| **Tier 2** | Standard | Development tools | Docker Registry, CI runners |
| **Tier 3** | Optional | Nice-to-have services | Media servers, utilities |

### Security Scanning

Automated security scanning runs on every change:

```yaml
# In GitHub Actions pipeline
- Checkov scans Dockerfiles for misconfigurations
- Trivy performs config scans on Dockerfiles
- Trivy scans built images for vulnerabilities
- CRITICAL findings block deployment
- Scan results uploaded as artifacts
```

**Security Gates**:
- ✅ Dockerfile best practices enforcement
- ✅ Base image vulnerability scanning
- ✅ Critical CVE detection and blocking
- ✅ Secrets detection in container layers

### Backup Strategy

Automated daily backups ensure cluster state preservation:

| Service | Schedule | Retention | Location |
|---------|----------|-----------|----------|
| **Consul** | Daily 2:00 AM PT | Configurable | /mnt/gdrive/consul-snapshots |
| **Nomad** | Daily 2:00 AM PT | Configurable | /mnt/gdrive/nomad-snapshots |

Features:
- Automatic snapshot creation
- Retention policy enforcement
- Retry logic for transient failures
- Journald logging for audit trail

---

## 📖 Make Targets Reference

### Setup & Dependencies

```bash
make init                     # First-time setup (install deps, fetch providers)
make install-cdktf            # Install CDKTF CLI
make deps                     # Update Go deps and fetch CDKTF providers
```

### Build Commands

```bash
make build                    # Build CDKTF application (nomad-app)
make build-tools              # Build utility tools (validate-structure, nomad-query)
make build-all                # Build everything
```

### Deployment Commands

```bash
make synth                    # Generate Terraform JSON from CDKTF
make deploy                   # Deploy all infrastructure
make deploy-jobs JOBS=...     # Deploy specific categories (comma-separated)
make deploy-category CAT=...  # Deploy all jobs in one category
make plan                     # Show Terraform plan
make diff                     # Show CDKTF diff
```

### Validation Commands

```bash
make validate                 # Validate all Nomad job files
make validate-category CAT=...# Validate jobs in specific category
make check-structure          # Validate directory structure
make lint                     # Lint HCL files
make semgrep                  # Run Semgrep security scan
make trivy                    # Run Trivy config scan
```

### Formatting Commands

```bash
make fmt                      # Format Go code and Nomad jobs
make fmt-jobs                 # Format only Nomad jobs
```

### Category Management

```bash
make list-categories          # List all job categories
make category-report          # Detailed breakdown by category
```

### Development Commands

```bash
make test                     # Run Go tests
make lint-go                  # Run Go linter
make clean                    # Remove build artifacts
make clean-all                # Full clean including Go cache
```

### Query Tools

```bash
make query ARGS='...'         # Query Nomad jobs
# Examples:
make query ARGS='-category monitoring'
make query ARGS='-job prometheus'
```

---

## 📦 Nomad Job Categories

### Infrastructure (Tier 0) - Critical Services

**Purpose**: Core infrastructure required for cluster operation

- `traefik` - Reverse proxy and load balancer
- `cloudflared-tunnel` - Secure edge access via Cloudflare
- `nginx-resume` - Static site hosting

**Characteristics**:
- Must be highly available
- Minimal restart tolerance
- Health checks with quick failover

### Monitoring (Tier 1) - Important Services

**Purpose**: Observability and alerting infrastructure

- `prometheus` - Metrics collection and alerting rules
- `grafana` - Metrics visualization and dashboards
- `alertmanager` - Alert routing and notifications
- `node-exporter` - System metrics (runs on all nodes)
- `blackbox-exporter` - External endpoint monitoring

**Characteristics**:
- Important but not critical
- Can tolerate brief downtime
- Essential for operations

### Logging (Tier 1) - Important Services

**Purpose**: Centralized log aggregation and analysis

- `loki` - Log aggregation server
- `promtail` - Log collection agent (runs on all nodes)

**Characteristics**:
- Stores 5 days of logs
- Retention policies enforced
- Queries via Grafana

### Development (Tier 2) - Standard Services

**Purpose**: Development and CI/CD tooling

- `registry` - Private Docker registry with mirror capability
- `registry-ui` - Web interface for registry management
- `github-actions-runners` - Self-hosted CI/CD runners

**Characteristics**:
- Development workflow enablers
- Can be redeployed without data loss
- Resource-intensive workloads

### Backup (Tier 2) - Standard Services

**Purpose**: Automated state backup and recovery

- `consul-snapshot` - Daily Consul state backup
- `nomad-snapshot` - Daily Nomad state backup

**Characteristics**:
- Batch jobs (periodic execution)
- Run on specific nodes with storage access
- Configurable retention policies

### Utility (Tier 3) - Optional Services

**Purpose**: Helper jobs and resource management

- `reserve-k3s-capacity-dummy` - Reserve resources for external workloads

**Characteristics**:
- Nice-to-have functionality
- Lowest priority for resources
- Can be stopped without impact

---

## 🔐 Security Considerations

### Access Control

**Service Protection**:
- All services protected by Consul/Nomad ACLs
- Vault workload identity for secret access
- LAN-only access for sensitive dashboards
- Traefik middleware for IP allowlisting

**ACL Hierarchy**:
```
Management Token (admin)
  ├── Operator Token (SRE daily use)
  ├── Read-Only Token (dashboards/auditing)
  ├── Service Tokens (per-service least privilege)
  └── Workload Identity (ephemeral, scoped)
```

### Encryption

**In Transit**:
- TLS for all HTTP/RPC communication
- mTLS for server-to-server communication
- Gossip encryption for Consul/Nomad

**At Rest**:
- Vault-managed secrets
- Encrypted data bags for Chef
- No secrets in version control

### Network Security

**Firewall Rules**:
- Host networking with UFW/iptables rules
- Service-specific port allowlisting
- LAN-only access by default

**Container Security**:
- No privileged containers (except where absolutely required)
- CNI-based container networking
- Resource limits enforced
- Read-only root filesystems where possible

### Secrets Management

**Vault Integration**:
```hcl
# Jobs authenticate via workload identity
identity {
  env  = true
  file = true
  aud  = ["vault.io"]
}

vault {
  role = "nomad-workloads"
}

# Secrets templated into environment
template {
  data = <<EOH
{{ with secret "kv/data/myapp" }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
EOH
  destination = "secrets/app.env"
  env         = true
}
```

**Best Practices**:
- No hardcoded credentials
- Secrets rotation via Vault
- Least-privilege access policies
- Audit logging enabled

---

## 🤝 Contributing

This is a personal homelab project, but suggestions and improvements are welcome!

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add some amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Standards

- **Go**: Follow standard Go conventions, use `gofmt` and `golangci-lint`
- **HCL**: Use `nomad fmt` for Nomad job files
- **Chef**: Follow Cookstyle conventions
- **Documentation**: Update README for significant changes

---

## 📄 License

**All Rights Reserved** - Personal Infrastructure Project

This is a personal homelab project. The code is provided for educational and reference purposes. Please respect the license terms.

---

## 🙏 Acknowledgments

Built with these excellent open-source projects:

- [HashiCorp Nomad](https://www.nomadproject.io/) - Workload orchestration
- [HashiCorp Consul](https://www.consul.io/) - Service networking
- [OpenBao](https://openbao.org/) - Secrets management
- [Traefik](https://traefik.io/) - Cloud-native reverse proxy
- [Prometheus](https://prometheus.io/) - Monitoring and alerting
- [Grafana](https://grafana.com/) - Observability platform
- [Loki](https://grafana.com/oss/loki/) - Log aggregation

---

<div align="center">

**⚠️ Production Deployment Notice**

This infrastructure is designed for self-hosted/homelab environments.

Production deployments should review security configurations, especially TLS verification settings and ACL policies.

---

Made with ❤️ for the homelab community

</div>
