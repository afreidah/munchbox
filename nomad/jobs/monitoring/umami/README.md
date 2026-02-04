# Umami

Privacy-focused web analytics platform that tracks page views and visitor
sessions without cookies or personal data collection. Provides city-level
geolocation using the free DB-IP database. Tracked sites include the
resume, dashboard, and various cluster services via a small JS snippet
injected by Traefik middleware.

## Architecture

A prestart task downloads the latest DB-IP GeoLite City database into the
shared alloc directory. The main umami task reads this file for geolocation
enrichment. The database is re-downloaded on every restart to stay current
with monthly DB-IP releases.

## Components

| Task           | Role                          | Lifecycle |
|----------------|-------------------------------|-----------|
| geoip-updater  | Download DB-IP city database  | prestart  |
| umami          | Analytics web application     | main      |

## Notable Configuration

- Runs on large Oracle Cloud nodes to keep analytics off the homelab
- Accessible at both `analytics.munchbox.cc` and `analytics.alexfreidah.com`
- No oauth2-proxy -- Umami needs to accept anonymous tracking requests
  from public sites
- Sends traces to Tempo via OpenTelemetry

## Dependencies

- **Patroni** -- PostgreSQL database (umami database)
- **Traefik** -- injects the tracking middleware on protected services
