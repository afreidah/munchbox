# g3-proxy

S3-compatible gateway backed by Gmail (metadata) and Google Drive
(object data) with a PostgreSQL index. Registered as one of the
backends behind s3-orchestrator (the `g3` backend), so the cluster
can route a slice of S3 traffic into free Google storage quota.

## Image

`registry.munchbox.cc/g3:v0.5.1`

## Hostname / exposure

- `g3-proxy.munchbox.cc`
- HTTPS through `oauth2-proxy-errors@file,oauth2-proxy@file`
- HTTP variant adds `cf-tunnel-https@file` (Cloudflare tunnel path)

## Placement

- `node_pool = default`, single instance
- Host network, static port 9001

## Dependencies

- PostgreSQL `g3` database via `haproxy-postgres.service.consul:5433`
  (sslmode require)
- Vault path `secret/data/g3` -- Gmail OAuth `client_id` /
  `client_secret` / `refresh_token`, S3 access/secret keys, db creds,
  bucket name
- Tempo at `tempo.service.consul:4317` for traces

## Notable configuration

- Health check path `/health/ready`
- `GOMAXPROCS=1`, `GOMEMLIMIT=700MiB`; resources cap at memory_max 1536
- Gmail label prefix `s3`; 20m read/write timeouts to ride out slow
  Drive uploads
- Consumed by s3-orchestrator as the `g3` backend (15 GB quota)
