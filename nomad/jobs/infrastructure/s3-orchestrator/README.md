# s3-orchestrator

Multi-backend S3 gateway. Presents one unified S3 endpoint to clients
and spreads objects across ~13 backends with replication, circuit
breakers, integrity scrubbing, and Vault-transit encryption.
Everything that writes S3 in the cluster (aptly, backups, etc.) goes
through here.

## Image

`registry.munchbox.cc/s3-orchestrator:v0.60.22`

## Hostname / exposure

- `s3.munchbox.cc`
- HTTPS through `oauth2-proxy-errors@file,oauth2-proxy@file`
- HTTP variant adds `cf-tunnel-https@file`
- Also reachable in-cluster at `s3-orchestrator.service.consul:9000`

## Placement

- `node_pool = default`, single instance
- Host network, static port 9000

## Dependencies

- PostgreSQL `s3_orchestrator` database via
  `haproxy-postgres.service.consul:5433` (sslmode require)
- Vault path `secret/data/s3-orchestrator` for db creds, admin/UI
  tokens, and one set of S3 credentials per backend (`oci_s3_*`,
  `r2_s3_*`, `e2_s3_*`, `ibm_s3_*`, `gcp_s3_*`, `b2_s3_*`,
  `g3_s3_*`, `supabase_s3_*`, `c2_s3_*`, `tigris_s3_*`,
  `minio_s3_*`, `minio_arm2_s3_*`)
- Vault transit mount `transit/keys/s3-orchestrator` for at-rest
  encryption; `pki_int/cert/ca` for the in-container CA bundle
- Tempo at `tempo.service.consul:4317` for traces
- Backends include OCI, Cloudflare R2, IDrive e2, IBM COS, GCS,
  Backblaze B2, g3 (Gmail/GDrive), Supabase, C2, Tigris, and two
  on-cluster MinIO instances

## Notable configuration

- Vault role `s3-orchestrator`: its own prefix plus the three `s3-bucket/*` keys and transit
- Routing strategy `spread`; replication factor 2
- Per-backend `disable_checksum` / `unsigned_payload` /
  `strip_sdk_headers` flags for GCS and e2 compatibility
- Backend circuit breaker: 3 failures, 30m open; cluster CB: 3
  failures, 1200s open, parallel broadcast on degraded
- Integrity scrubber every 24h; rebalance every 24h; pending-write
  reaper every 10m
- Rate limit 1500 rps / 2000 burst with RFC1918 trusted proxies
