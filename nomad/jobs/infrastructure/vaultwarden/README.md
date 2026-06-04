# vaultwarden

Self-hosted Bitwarden-compatible password manager. Web UI sits behind
oauth2-proxy, but the `/api`, `/identity`, `/icons`, and `/notifications`
paths bypass it so Bitwarden CLI, browser extensions, and mobile apps can
authenticate directly against Vaultwarden.

## image

`vaultwarden/server:1.36.0`

## hostname / exposure

- `vaultwarden.munchbox.cc`
- web UI routers: `oauth2-proxy-errors@file,oauth2-proxy@file`
  (plus `cf-tunnel-https@file` on the HTTP entrypoint)
- API routers: no oauth2-proxy (priority 20), so clients can hit
  `/api`, `/identity`, `/icons`, `/notifications` directly
- separate routers for direct HTTPS and the Cloudflare tunnel path

## placement

- constraint: `attr.cpu.arch = amd64`
- single instance, no node pin; Nomad schedules wherever amd64 capacity exists

## dependencies

- Patroni Postgres `vaultwarden` database, reached via
  `haproxy-postgres.service.consul:5433` (`DATABASE_URL=postgresql://...`)
- Vault `secret/data/vaultwarden`: admin token, DB creds, SMTP creds,
  signups flag, base64-encoded RSA key for JWT signing
- SMTP relay (creds from Vault) for invitations and password resets

## notable configuration

- `I_REALLY_WANT_VOLATILE_STORAGE=true` -- attachments live on the alloc's
  ephemeral disk; Postgres holds the vault itself
- RSA key materialized to `secrets/rsa_key.pem` from base64 in Vault
- websocket port `3012` is declared on the alloc but no Traefik router
  currently exposes it
- `kill_timeout = 30s`, `SIGTERM`
