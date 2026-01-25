# Munchbox Project Reference

## Environment Setup

**Always source the environment file before running nomad/consul/vault commands or infrastructure commands:**
```bash
source munchbox-env.sh
```

## General Guidelines

- **All code generated must follow `MUNCHBOX_STYLE_GUIDE.md`**
- **Always use Makefile tasks where possible**
- **When editing things on nodes, codify changes with Terraform/Terragrunt/Ansible wherever possible** - avoid manual changes that aren't tracked in code

## Deploying Nomad Jobs

From the munchbox root directory:
```bash
source munchbox-env.sh && cd nomad && make run JOB=<jobname>
```

**jobname** is just the name without path or extension. Examples: `grafana`, `traefik`, `patroni`, `prometheus`

### Job Types

1. **Pure Nomad jobs** - End with `.nomad.hcl`
   - These are standard Nomad job specifications

2. **Munchbox service jobs** - End with `.hcl` (no `.nomad` prefix)
   - These are variable files for the `munchbox-service` Nomad pack
   - Pack location: `nomad/packs/registry/munchbox-service/`

## SSH Access

- **Most nodes**: SSH as `root`
  ```bash
  ssh root@<node>
  ```

- **Oracle nodes**: SSH as `ubuntu`, then use `sudo`
  ```bash
  ssh ubuntu@<oracle-node>
  sudo <command>
  ```

Oracle nodes use a WireGuard tunnel to one of the bare metal Nomad nodes to enable communication with the cluster.

## Project Structure

- `nomad/jobs/` - Nomad job definitions organized by category
- `nomad/packs/registry/` - Nomad packs (including munchbox-service)
- `infrastructure/ansible/` - Ansible playbooks and roles
- `src/vault-cert-manager/` - Vault PKI certificate lifecycle manager

## Certificate Management

### vault-cert-manager
Manages certificates for infrastructure services:
- Consul server/client certs
- Nomad server/client certs
- Deployed via: `infrastructure/ansible/playbooks/vault-cert-manager.yml`

### Nomad Template Certs
Some containerized services get certs via Nomad templates with Vault PKI:
- Patroni/PostgreSQL - uses `pki_int/issue/postgres` role (TTL: 2160h)

### Let's Encrypt (External)
Public-facing services use Let's Encrypt via Certbot:
- Managed by: `nomad/jobs/infrastructure/certbot/certbot.nomad.hcl`
- Used by Traefik for `*.munchbox.cc`

## Alerting

Prometheus alert rules: `nomad/jobs/monitoring/prometheus/files/alert_rules.yml`

Alert groups include:
- infrastructure-health
- nomad-health
- vault-health
- vault-cert-manager-health
- postgresql-health
- redis-health
- And more...
