# Nextcloud

Self-hosted cloud storage and collaboration platform. Provides file sync,
sharing, and web-based document management. Uses the shared PostgreSQL
and Redis infrastructure for storage and caching.

## Architecture

The job runs two tasks in a single bridge-mode group. The main nextcloud
task runs the Apache-based Nextcloud image. A poststart sidecar runs the
Nextcloud cron script for background jobs (file scanning, cleanup, app
updates). Both tasks share the same volume mounts to ensure consistent
access to user data and configuration.

## Components

| Task      | Role                        | Lifecycle        |
|-----------|-----------------------------|------------------|
| nextcloud | Apache web server and app   | main             |
| cron      | Background job processor    | poststart sidecar|

## Notable Configuration

- API and sync paths (`/ocs`, `/remote.php`, `/public.php`) bypass
  oauth2-proxy because Nextcloud desktop/mobile clients authenticate
  directly with Nextcloud
- Web UI routes go through oauth2-proxy for additional access control
- User data on gdrive NFS (`/mnt/gdrive/nextcloud/data`); config and
  apps on local storage for faster access
- Bridge mode with explicit DNS for Consul resolution
- Canary deployment with task_states health check (no HTTP check during
  initial setup migrations)

## Dependencies

- **Patroni** -- PostgreSQL database (nextcloud database)
- **Redis Sentinel** -- file locking and session cache
- **OAuth2 Proxy** -- web UI authentication
