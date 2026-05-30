# cloudflare-log-collector

Polls the Cloudflare GraphQL Analytics API for firewall events and
HTTP traffic stats on the `munchbox.cc` and `alexfreidah.com` zones.
Ships firewall events to Loki as structured JSON, exposes HTTP-traffic
counters via Prometheus, and traces each poll cycle into Tempo. The
UI lives in the separate `cloudflare-log-collector-webpage` job.

## Image

`registry.munchbox.cc/cloudflare-log-collector:v0.1.12`

## Hostname / exposure

- No traefik (`traefik.enable=false`)
- Metrics on host port 9102 (`/health`, `/metrics`)
- Scraped by Prometheus via Consul service discovery

## Placement

- `node_pool = default`, single instance
- Host network

## Dependencies

- Cloudflare GraphQL API (token from Vault `secret/data/cloudflare`,
  field `api_token`)
- Loki at `loki.service.consul:3100` (tenant_id `fake`, batch 100)
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Zones hardcoded in the template: `munchbox.cc`
  (`bd3f7236466255155ab59b9d21cd88fd`) and `alexfreidah.com`
  (`79e647e591f69cc27254bf4771464619`)
- Poll interval 1m with a 1h backfill window
- Trace sample rate 1.0 (every cycle)
- JSON structured logs at `info`
