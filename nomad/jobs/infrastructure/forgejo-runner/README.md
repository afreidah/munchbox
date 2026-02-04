# Forgejo Runner

Forgejo Actions CI runner (act_runner) that executes GitHub Actions
compatible workflows for the self-hosted Forgejo instance. Runs two
instances on separate large Oracle Cloud nodes to parallelize CI
workloads.

## Notable Configuration

- Connects directly to Forgejo's internal address via Consul service
  discovery, bypassing oauth2-proxy for runner registration
- Docker socket passthrough with privileged mode for container-based
  workflow steps
- Distinct hosts constraint ensures the two runners land on different
  Oracle nodes for resilience
- Registration token from Vault; runners auto-register on first start

## Dependencies

- **Forgejo** -- receives workflow jobs from the Forgejo server
- **Vault** -- runner registration token
