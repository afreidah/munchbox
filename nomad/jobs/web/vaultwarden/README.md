# Vaultwarden

Self-hosted password manager compatible with all Bitwarden clients (browser
extensions, mobile apps, CLI). Stores encrypted vault data on the
`gdrive-secondary` NFS mount for durability.

## Architecture

Vaultwarden runs as a single task in bridge mode with separate HTTP and
WebSocket ports. Traefik routing splits API paths (`/api`, `/identity`,
`/icons`, `/notifications`) from the web vault UI. API routes bypass
oauth2-proxy because Bitwarden clients authenticate directly with
Vaultwarden -- wrapping them in OAuth would break all client sync.

## Notable Configuration

- Uses Nomad 1.11 native `secret` block for Vault credential injection
  instead of template-based env files
- Canary deployment with auto-promote for zero-downtime updates
- WebSocket support enabled for real-time sync notifications
- Admin panel token stored in Vault; signups controlled via Vault secret
- Dual routers for both direct HTTPS and Cloudflare tunnel access

## Dependencies

- **OAuth2 Proxy** -- protects web vault UI (API paths bypass it)
- **Vault** -- admin token and signup configuration
