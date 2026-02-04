# Forgejo

Self-hosted Git repository service providing GitHub-compatible workflows,
push mirroring to GitHub, and integrated CI via Forgejo Actions. All
munchbox infrastructure code and application source lives here.

## Architecture

The job runs in bridge mode with two exposed ports: HTTP for the web
interface and API, and a static SSH port (2222) for git+ssh operations.
A prestart init-config task renders the full `app.ini` configuration from
Vault secrets and copies it to the persistent data volume before the main
Forgejo task starts.

The static SSH port prevents canary deployments -- two instances cannot
bind the same port simultaneously. Updates use rolling deploys instead.

## Notable Configuration

- Multiple Traefik routers with different priority levels separate API
  and git operations (no OAuth) from the web UI (with OAuth)
- Uses PostgreSQL, Redis cache, Redis sessions, and Redis queues --
  all pointing at the shared cluster infrastructure
- Push mirroring enabled with 8-hour default interval
- Webhook ALLOWED_HOST_LIST restricts callbacks to internal services
  and `*.munchbox.cc` to prevent SSRF
- Data persists on gdrive NFS mount at `/mnt/gdrive/forgejo`
- OpenTelemetry tracing enabled to Tempo

## Dependencies

- **Patroni** -- PostgreSQL database backend (forgejo database)
- **Redis Sentinel** -- cache, sessions, and task queues
- **OAuth2 Proxy** -- web UI authentication (API and git bypass it)
- **Forgejo Runner** -- executes CI workflows submitted to this server
