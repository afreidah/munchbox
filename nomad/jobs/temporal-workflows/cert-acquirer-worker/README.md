# cert-acquirer-worker

Temporal worker that issues the `*.munchbox.cc` wildcard certificate via
ACME DNS-01 (Cloudflare) using the `go-acme/lego` library and publishes
the cert+key to `secret/traefik/wildcard` for both Traefiks to read.
Started on schedule by a Temporal Schedule (managed in
`infrastructure/terragrunt`). Replaces the standalone weekly Nomad
periodic `cert-acquirer` job.

## Image

`registry.munchbox.cc/cert-acquirer-worker:v0.1.1`

## Hostname / exposure

- No traefik
- Metrics on container port 9090, scraped via Consul

## Placement

- Any client node (`node_pool = "all"`); needs outbound to Let's
  Encrypt + Cloudflare, plus `.consul` for Vault/Temporal/Tempo

## Dependencies

- Temporal at `temporal-server.service.consul:7233` on the
  `cert-task-queue`
- Vault at `https://vault.service.consul:8200`, authenticated with the
  task's Workload Identity (role `cert-acquirer-worker`); the WI token
  is read from `/secrets/vault_token` and TLS is trusted via the mounted
  vault intermediate CA
- Cloudflare DNS API token from `secret/data/cloudflare-wandns` (read
  through Vault, not templated)
- Vault KV the worker reads/writes: `traefik/wildcard`,
  `traefik/wildcard-staging`, `traefik/acme-account`
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Self-authenticating: the only secret material in the job is the
  Workload Identity; every other credential is pulled through Vault
- The ACME account is persisted to `secret/traefik/acme-account` so
  registration happens once, not on every run
- Custom `dns { servers = ["127.0.0.53"] }` so `.consul` and public
  names both resolve through the host stub resolver
- 30s kill timeout to let in-flight Temporal activities flush
