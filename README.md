<div align="center">

# Munchbox Cloud — Homelab Infrastructure Platform

### Production-Grade Self-Hosted Infrastructure on HashiCorp Stack

[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red.svg)](LICENSE)
[![Nomad](https://img.shields.io/badge/Nomad-v1.11.1-00CA8E?logo=nomad)](https://www.nomadproject.io/)
[![Consul](https://img.shields.io/badge/Consul-v1.22.2-F24C53?logo=consul)](https://www.consul.io/)
[![Vault](https://img.shields.io/badge/Vault-v1.15.4-000000?logo=vault)](https://www.vaultproject.io/)
[![Traefik](https://img.shields.io/badge/Traefik-v3.6.6-24A1C1?logo=traefikproxy)](https://traefik.io/)
[![Go](https://img.shields.io/badge/Go-1.23+-00ADD8?logo=go)](https://golang.org/)

---

**A complete infrastructure platform featuring workload orchestration, service discovery, secrets management, and comprehensive monitoring—all managed as code with Terragrunt/Terraform and Ansible.**

[Features](#key-features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Documentation](#documentation)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
  - [Core Stack](#core-stack)
  - [Infrastructure Services](#infrastructure-services)
  - [DNS Architecture](#dns-architecture)
- [Directory Structure](#directory-structure)
- [Technology Stack](#technology-stack)
- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [Initial Setup](#initial-setup)
  - [Service Access](#service-access)
- [Feature Details](#feature-details)
  - [vault-cert-manager](#vault-cert-manager)
  - [Nomad Pack Templates](#nomad-pack-templates)
  - [High Availability Databases](#high-availability-databases)
  - [Security Scanning](#security-scanning)
  - [Backup Strategy](#backup-strategy)
- [Make Targets Reference](#make-targets-reference)
- [Nomad Job Categories](#nomad-job-categories)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This project implements a complete homelab infrastructure using modern DevOps practices and cloud-native technologies. It provides a robust foundation for running containerized workloads, managing secrets, service discovery, and monitoring across a distributed hybrid cluster spanning on-premises Proxmox nodes and Oracle Cloud Infrastructure.

Built on the HashiCorp stack (Nomad, Consul, Vault) and managed through Infrastructure as Code using Terragrunt/Terraform modules and Ansible, this platform demonstrates enterprise-grade patterns in a self-hosted environment.

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Infrastructure as Code** | Terragrunt + Terraform modules for multi-cloud infrastructure (Proxmox, OCI, AWS) |
| **Configuration Management** | Ansible playbooks and roles for node provisioning and configuration |
| **Workload Orchestration** | Nomad with pure HCL jobs and Nomad Pack templates (munchbox-service pack) |
| **Secrets Management** | HashiCorp Vault with workload identity and PKI certificate automation |
| **Certificate Lifecycle** | vault-cert-manager for automated PKI cert issuance, renewal, and health monitoring |
| **Service Discovery** | Consul for service discovery, health checking, and DNS |
| **High Availability** | Patroni for PostgreSQL HA, Redis Sentinel for Redis HA |
| **Full Observability** | Prometheus, Grafana, Loki, Tempo, Alertmanager with Telegram notifications |
| **Security Scanning** | Trivy for container and infrastructure vulnerability scanning |
| **CI/CD** | Forgejo with self-hosted act_runner for GitHub Actions-compatible workflows |

---

## Architecture

### Core Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **HashiCorp Nomad** | v1.11.1 | Workload scheduling and deployment |
| **HashiCorp Consul** | v1.22.2 | Service discovery and DNS |
| **HashiCorp Vault** | v1.15.4 | Secrets management and PKI |
| **Traefik** | v3.6.6 | Dynamic routing with automatic TLS |
| **Prometheus** | Latest | Metrics collection and alerting |
| **Grafana** | Latest | Metrics visualization |
| **Loki** | Latest | Log aggregation |
| **Tempo** | Latest | Distributed tracing |

### Infrastructure Services

- **Edge Access**: Cloudflare Tunnel for secure external access
- **Container Registry**: Private Docker registry with web UI
- **Database HA**: Patroni for PostgreSQL, Redis Sentinel for Redis, HAProxy for failover-safe connection routing
- **Certificate Management**: vault-cert-manager for automated PKI lifecycle
- **Logging**: Loki + Promtail for log aggregation
- **Alerting**: Alertmanager with Telegram notifications
- **Backup**: Temporal workflows for automated backup orchestration
- **DNS**: CoreDNS with dnsmasq for Consul DNS forwarding

### DNS Architecture

Each node runs a local DNS stack that provides service discovery and external resolution:

```
Container/Process → dnsmasq (127.0.0.53)
                         ↓
      ┌──────────────────┴──────────────────┐
      │ .consul queries    │ other queries  │
      ↓                    ↓                │
Consul (8600)        CoreDNS (5353)         │
                           ↓                │
                     Pi-holes (round-robin) │
                           ↓                │
                        Unbound             │
                           ↓                │
                   Root DNS Servers         │
                           ↓                │
                [fallback if CoreDNS down]──┘
```

**Components:**

| Component | Port | Purpose |
|-----------|------|---------|
| **dnsmasq** | 127.0.0.53 | Local DNS forwarder, routes queries to appropriate upstream |
| **Consul DNS** | 8600 | Service discovery for `.consul` domain (e.g., `redis-primary.service.consul`) |
| **CoreDNS** | 5353 | System job on every node, load balances to Pi-holes with health checks |
| **Pi-hole** | 53 | Ad-blocking DNS servers (green, logan) |
| **Unbound** | 5335 | Recursive resolver on Pi-hole hosts, queries root servers directly |

**Key Features:**

- **Local-first resolution**: Every node has its own DNS stack, no single point of failure
- **Automatic failover**: dnsmasq falls back to Pi-holes directly if CoreDNS is down
- **Service discovery**: Consul DNS enables dynamic service lookup across the cluster
- **Health-checked upstreams**: CoreDNS monitors Pi-hole health and removes failed servers
- **Privacy-focused**: Unbound resolves directly from root servers, no third-party DNS

**Configuration:**

- Ansible playbook: `infrastructure/ansible/playbooks/configure-local-consul-dns.yml`
- CoreDNS job: `nomad/jobs/infrastructure/coredns/coredns.nomad.hcl`
- Bridge-mode containers use `${attr.unique.network.ip-address}` for DNS with Pi-hole fallbacks

---

## Directory Structure

```
.
├── .github/workflows/           # CI/CD pipelines
│   └── docker-ci.yml            # Waypoint Docker build pipeline
│
├── src/                         # Custom applications
│   ├── vault-cert-manager/      # Vault PKI certificate lifecycle manager (Go)
│   ├── trivy-dashboard/         # Vulnerability dashboard for Trivy (Go)
│   ├── temporal-jobs/           # Temporal workflow workers
│   │   └── temporal-backup-worker/
│   ├── dashboard/               # Hugo-based link dashboard
│   ├── resume/                  # Personal resume site
│   ├── s3-proxy/                # S3 proxy service (Go)
│   └── theme-server/            # Theme server for dashboards
│
├── nomad/                       # Nomad workload definitions
│   ├── jobs/                    # Job specifications
│   │   ├── backup/              # Backup jobs (Temporal triggers)
│   │   ├── games/               # Game servers (Zomboid)
│   │   ├── infrastructure/      # Core services (Traefik, Patroni, Redis, etc.)
│   │   ├── logging/             # Loki, Promtail, Tempo
│   │   ├── media/               # Media stack (Jellyfin, *arr apps, Deluge)
│   │   ├── monitoring/          # Prometheus, Grafana, exporters
│   │   └── web/                 # Web apps (Nextcloud, Vaultwarden, dashboard)
│   └── packs/registry/          # Nomad Pack templates
│       └── munchbox-service/    # Reusable service pack
│
├── infrastructure/
│   ├── ansible/                 # Configuration management
│   │   ├── inventory/           # Host inventory and group vars
│   │   ├── playbooks/           # Deployment playbooks
│   │   └── roles/               # Reusable roles
│   │       ├── consul/          # Consul agent setup
│   │       ├── nomad/           # Nomad agent setup
│   │       ├── vault/           # Vault server setup
│   │       ├── vault-cert-manager/  # Certificate manager deployment
│   │       ├── wireguard/       # WireGuard VPN tunnels
│   │       └── ...              # Other roles
│   │
│   ├── terraform/modules/       # Reusable Terraform modules
│   │   ├── bootstrap/           # Node bootstrap (cloud-init)
│   │   ├── compute-oci/         # OCI compute instances
│   │   ├── compute-proxmox/     # Proxmox VMs
│   │   ├── consul-acls/         # Consul ACL policies and tokens
│   │   ├── nomad-acls/          # Nomad ACL policies and tokens
│   │   ├── vault-config/        # Vault configuration
│   │   ├── kms-oci/             # OCI KMS for Vault auto-unseal
│   │   └── ...                  # Other modules
│   │
│   └── terragrunt/              # Environment configurations
│       ├── _env_helpers/        # Shared Terragrunt includes
│       ├── global/              # Global resources (ACLs, DNS, secrets)
│       ├── oci/                 # Oracle Cloud nodes
│       ├── proxmox/             # On-prem Proxmox cluster
│       └── aws/                 # AWS resources
│
└── docker/                      # Custom Docker images
    ├── Makefile                 # Docker build automation
    ├── deluge-vpn/              # VPN-enabled torrent client
    ├── patroni/                 # Custom Patroni image
    └── ops-build-image/         # CI/CD toolchain image
```

---

## Technology Stack

### Infrastructure Layer

- **IaC**: Terragrunt + Terraform modules for multi-cloud (Proxmox, OCI, AWS)
- **Configuration**: Ansible playbooks and roles
- **Orchestration**: Nomad with Docker driver, Nomad Pack templates
- **Service Discovery**: Consul with DNS via CoreDNS/dnsmasq
- **Secrets**: HashiCorp Vault with workload identity (JWT auth)
- **Networking**: WireGuard tunnels, Traefik reverse proxy
- **Virtualization**: Proxmox VE for on-prem, OCI for cloud

### Monitoring & Observability

- **Metrics**: Prometheus, Node Exporter, Blackbox Exporter, custom exporters
- **Visualization**: Grafana with pre-configured dashboards
- **Logging**: Loki + Promtail for log aggregation
- **Tracing**: Tempo for distributed tracing
- **Alerting**: Alertmanager with Telegram integration
- **Security Scanning**: Trivy server with custom dashboard

### Security

- **Vulnerability Scanning**: Trivy for containers and infrastructure
- **TLS**: Vault PKI with vault-cert-manager for automated rotation
- **ACLs**: Fine-grained access control across Nomad, Consul, Vault
- **Encryption**: Gossip encryption, mTLS for service communication
- **Secrets**: Vault workload identity, no hardcoded credentials
- **Authentication**: OAuth2 Proxy for web service SSO

### Development Tools

- **CI/CD**: Forgejo with act_runner (GitHub Actions compatible)
- **Registry**: Private Docker registry with web UI
- **Workflows**: Temporal for backup orchestration and automation
- **Linting**: golangci-lint for Go code

---

## Quick Start

### Prerequisites

- **Ansible** for node configuration
- **Terraform** and **Terragrunt** for infrastructure provisioning
- **Consul**, **Nomad**, and **Vault** CLI tools
- **Docker** for container builds
- **Go** 1.23+ for building custom applications
- **Make** for automation

### Environment Setup

Always source the environment file before running commands:
```bash
source munchbox-env.sh
```

### Deploying Nomad Jobs

From the munchbox root directory:
```bash
source munchbox-env.sh && cd nomad && make run JOB=<jobname>
```

Examples:
```bash
make run JOB=grafana      # Deploy Grafana
make run JOB=traefik      # Deploy Traefik
make plan JOB=prometheus  # Plan changes for Prometheus
make list                 # Show all available jobs
```

**Job Types:**
- `.nomad.hcl` files — Pure Nomad job specifications
- `.hcl` files — Variable files for the `munchbox-service` Nomad Pack

### Infrastructure Provisioning

Terragrunt manages multi-cloud infrastructure:
```bash
cd infrastructure/terragrunt/proxmox/cluster
terragrunt apply

cd infrastructure/terragrunt/oci/oracle-arm-1
terragrunt apply
```

### Node Configuration

Ansible playbooks configure nodes:
```bash
cd infrastructure/ansible
ansible-playbook playbooks/vault-cert-manager.yml -l nomad_cluster
```

### Service Access

Once deployed, services are available at:

| Service | URL | Purpose |
|---------|-----|---------|
| **Nomad UI** | https://nomad.munchbox.cc | Workload management |
| **Consul UI** | https://consul.munchbox.cc | Service discovery |
| **Vault UI** | https://vault.munchbox.cc | Secrets management |
| **Grafana** | https://grafana.munchbox.cc | Metrics visualization |
| **Prometheus** | https://prometheus.munchbox.cc | Metrics collection |
| **Traefik** | https://traefik.munchbox.cc | Reverse proxy dashboard |
| **Alertmanager** | https://alertmanager.munchbox.cc | Alert management |
| **Forgejo** | https://forgejo.munchbox.cc | Git hosting and CI/CD |
| **Nextcloud** | https://cloud.munchbox.cc | File sync and sharing |

> **Note**: All services are LAN-restricted via OAuth2 Proxy, except for the public resume site accessible via Cloudflare Tunnel.

---

## Feature Details

### vault-cert-manager

Automated certificate lifecycle management for infrastructure services:

- **Automated Issuance**: Issues certificates from Vault PKI when missing
- **Renewal**: Renews certificates before expiration with jitter
- **Web Dashboard**: Per-node UI showing certificate status with manual rotation
- **Aggregator Mode**: Centralized dashboard discovering all instances via Consul
- **Out-of-Sync Detection**: Identifies when disk certs differ from running services
- **Prometheus Metrics**: `vault_cert_*` metrics for monitoring
- **Post-Change Hooks**: Configurable scripts for service reloads

Deployed via Ansible to all cluster nodes, manages Consul and Nomad TLS certificates.

### Nomad Pack Templates

The `munchbox-service` pack provides a reusable template for common service patterns:

- Standardized job structure with consistent metadata
- Vault integration for secrets
- Traefik labels for automatic routing
- Consul service registration
- Resource defaults with overrides

Jobs using the pack define variables (`.hcl` files), while complex jobs use pure Nomad HCL (`.nomad.hcl` files).

### High Availability Databases

**PostgreSQL with Patroni:**
- Automatic leader election and failover
- Streaming replication
- Health checks via Consul

**Redis with Sentinel:**
- Master/replica replication
- Sentinel quorum for automatic failover
- Dynamic master discovery via Consul DNS

**HAProxy Database Proxy:**
- TCP proxy in front of both Patroni and Redis Sentinel
- Applications connect to `haproxy-postgres.service.consul:5433` and `haproxy-redis.service.consul:6380`
- Health-checks Patroni REST API and Redis replication role to route to the current primary
- On failover, immediately kills stale connections (`on-marked-down shutdown-sessions`) so apps reconnect to the new primary without manual restart
- Backends discovered via HAProxy DNS resolver against Consul DNS

### Security Scanning

Trivy server provides continuous vulnerability scanning:

- Container image scanning
- Custom dashboard (`trivy-dashboard`) for vulnerability visibility
- Integration with Prometheus for alerting

### Backup Strategy

Temporal workflows orchestrate automated backups:

| Data | Schedule | Retention | Location |
|------|----------|-----------|----------|
| **Nomad** snapshots | Daily 2 AM PT | 7 days | /mnt/gdrive/nomad-snapshots |
| **Consul** snapshots | Daily 2 AM PT | 7 days | /mnt/gdrive/consul-snapshots |
| **Vault** snapshots | Daily 2 AM PT | 7 days | /mnt/gdrive/vault-snapshots |

The `temporal-backup-worker` runs continuously listening for workflow tasks, while `temporal-backup-trigger` dispatches the daily backup workflow.

---

## 📖 Make Targets Reference

### Nomad Jobs (`cd nomad`)

```bash
source munchbox-env.sh && cd nomad

make list                     # List all available jobs with types
make run JOB=<name>           # Deploy a job (auto-detects pack vs raw HCL)
make plan JOB=<name>          # Preview job changes
make render JOB=<name>        # Show generated HCL (useful for debugging)
make validate JOB=<name>      # Validate job syntax
make stop JOB=<name>          # Stop running job
make purge JOB=<name>         # Stop and purge job

# Batch operations
make render-all               # Render all jobs
make plan-all                 # Plan all jobs
make validate-all             # Validate all jobs
```

**Job Detection:**
- Files ending in `.nomad.hcl` → raw HCL (`nomad job run`)
- Files with `# PACK: <name>` → uses specified pack
- All other `.hcl` files → uses `munchbox-service` pack

### Infrastructure (`cd infrastructure`)

```bash
# VM Provisioning (Proxmox)
make tf-init                  # Initialize Terraform
make tf-plan                  # Preview VM changes
make tf-apply                 # Provision VMs
make tf-output                # Show VM details
make tf-destroy               # Destroy all VMs

# Node Management
make generate                 # Generate inventory from nodes.yml
make show-nodes               # Display node configuration
make add-node VM=<name>       # Configure node (VM or bare-metal)
make add-vm VM=<name>         # Full VM workflow: generate + tf-apply + add-node

# Consul ACL Management
make consul-prereqs           # Copy certs and enable Vault KV
make consul-acl-init          # Initialize Consul ACL Terraform
make consul-acl-plan          # Preview ACL changes
make consul-acl-apply         # Apply ACL configuration

# Vault Configuration
make vault-config-init        # Initialize Vault config Terraform
make vault-config-plan        # Preview Vault changes
make vault-config-apply       # Apply Vault configuration
```

### Docker Images (`cd docker`)

```bash
make apps                     # List discovered Docker apps
make build                    # Build all images
make build-app APP=<name>     # Build specific app

# Security Scanning
make checkov                  # Scan Dockerfiles with Checkov
make trivy                    # Scan configs with Trivy
make trivy-image              # Scan built images (fails on CRITICAL)
make security                 # Run all security scans

# Multi-Architecture Builds
make buildx-setup             # Set up BuildKit for multi-arch
make publish-multiarch        # Build and push amd64 + arm64 images
```

### Ansible Playbooks (`cd infrastructure/ansible`)

```bash
# Run playbooks directly with ansible-playbook
ansible-playbook playbooks/nomad-cluster.yml        # Full cluster setup
ansible-playbook playbooks/add-node.yml -e target_host=<node>
ansible-playbook playbooks/vault-cert-manager.yml   # Deploy cert manager
```

---

## 📦 Nomad Job Categories

### Infrastructure - Core Services

**Purpose**: Core infrastructure required for cluster operation

- `traefik` - Reverse proxy and load balancer
- `cloudflared-tunnel` - Secure edge access via Cloudflare
- `coredns` - DNS resolution for service discovery
- `keepalived` - Virtual IP failover
- `certbot` - Let's Encrypt certificate management
- `oauth2-proxy` - Authentication proxy for services
- `patroni` - HA PostgreSQL with Patroni orchestration
- `redis-sentinel` - HA Redis with Sentinel failover
- `haproxy` - Database failover proxy for Patroni and Redis
- `postgres-shared` / `postgres-replica` - Standalone PostgreSQL instances
- `redis-shared` - Standalone Redis instance
- `temporal` - Workflow orchestration (for backups, scans)
- `forgejo` - Self-hosted Git server (Gitea fork)
- `forgejo-runner` - CI/CD runners (act_runner)
- `registry` - Private Docker registry with mirror capability
- `trivy-server` - Vulnerability scanning server
- `theme-server` - CSS theme serving for unified UI
- `vault-ui` - HashiCorp Vault web interface

### Monitoring - Observability Stack

**Purpose**: Metrics collection, visualization, and alerting

- `prometheus` - Metrics collection and alerting rules
- `grafana` - Metrics visualization and dashboards
- `alertmanager` - Alert routing and notifications
- `node-exporter` - System metrics (runs on all nodes)
- `blackbox-exporter` - External endpoint monitoring
- `postgres-exporter` / `postgres-replica-exporter` - PostgreSQL metrics
- `redis-exporter` - Redis metrics
- `nextcloud-exporter` - Nextcloud metrics
- `trivy-dashboard` - Vulnerability scan dashboard
- `umami` - Privacy-focused web analytics

### Logging - Log Aggregation

**Purpose**: Centralized log collection and tracing

- `loki` - Log aggregation server
- `promtail` - Log collection agent (runs on all nodes)
- `tempo` - Distributed tracing

### Web - User Applications

**Purpose**: User-facing web applications

- `dashboard` - Munchbox landing page
- `nginx-resume` - Personal resume/portfolio site
- `nextcloud` - Self-hosted cloud storage
- `vaultwarden` - Bitwarden-compatible password manager
- `health-checker` - Service health status page

### Media - Media Management

**Purpose**: Media streaming and management (the *arr stack)

- `jellyfin` - Media streaming server
- `sonarr` - TV show management
- `radarr` - Movie management
- `lidarr` - Music management
- `readarr` - Book/audiobook management
- `prowlarr` - Indexer manager
- `kavita` - Comic/manga reader
- `deluge` - BitTorrent client
- `ersatz` - Content request system
- `cloudflaresolver` - Cloudflare bypass for indexers

### Games - Game Servers

**Purpose**: Self-hosted game servers

- `zomboid` - Project Zomboid dedicated server

### Backup - Automated Backups

**Purpose**: Scheduled backup workflows via Temporal

- `temporal-backup-worker` - Backup execution worker
- `temporal-backup-trigger` - Daily backup scheduler
- `temporal-trivy-trigger` - Scheduled vulnerability scans

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
- mTLS for server-to-server communication (via vault-cert-manager)
- Gossip encryption for Consul/Nomad

**At Rest**:
- Vault-managed secrets
- Ansible Vault for sensitive variables
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
- **HCL**: Use `nomad fmt` for Nomad job files, `terraform fmt` for Terraform
- **Ansible**: Follow ansible-lint conventions
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
- [HashiCorp Vault](https://www.vaultproject.io/) - Secrets management
- [Traefik](https://traefik.io/) - Cloud-native reverse proxy
- [Prometheus](https://prometheus.io/) - Monitoring and alerting
- [Grafana](https://grafana.com/) - Observability platform
- [Loki](https://grafana.com/oss/loki/) - Log aggregation
- [Patroni](https://github.com/patroni/patroni) - HA PostgreSQL
- [Temporal](https://temporal.io/) - Workflow orchestration
- [Forgejo](https://forgejo.org/) - Self-hosted Git
- [Terragrunt](https://terragrunt.gruntwork.io/) - Terraform wrapper

---

<div align="center">

**⚠️ Production Deployment Notice**

This infrastructure is designed for self-hosted/homelab environments.

Production deployments should review security configurations, especially TLS verification settings and ACL policies.

---

Made with ❤️ for the homelab community

</div>
