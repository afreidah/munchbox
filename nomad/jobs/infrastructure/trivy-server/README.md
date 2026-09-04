# trivy-server

Aqua Trivy in persistent server mode. The backup worker and other clients
call the HTTP API instead of spawning CLI processes, avoiding redundant
vuln-database downloads and enabling concurrent scans.

## Image

`aquasec/trivy:0.72.0`

## Hostname / exposure

- Internal-only Consul service `trivy-server`
- HTTP API on static port 4954
- No Traefik tags

## Placement

- Constraint: `meta.cloud != oracle` (Oracle pulls are slow and the vuln-DB
  sync is bandwidth-heavy)
- `count = 1`, otherwise unconstrained; Nomad reschedules on failure
- Canary 1 with `auto_promote = true` for zero-downtime updates

## Dependencies

- Redis via `haproxy-redis.service.consul:6380` as the vuln-DB cache backend
- Vault `secret/data/redis-shared` (Redis password) via the `trivy-server` role
- Temporal backup worker is the main caller

## Notable configuration

- `TRIVY_CACHE_BACKEND=redis://...` rendered from Vault
- 100 MHz / 512 MiB; memory left at 512 because vuln-DB sync spikes OOM'd at
  256
- Health: `GET /healthz`, `require_healthy` on update
