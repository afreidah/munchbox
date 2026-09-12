# s3-orchestrator

Multi-backend S3 gateway. Presents one unified S3 endpoint to clients
and spreads objects across ~13 backends with replication, circuit
breakers, integrity scrubbing, and Vault-transit encryption.
Everything that writes S3 in the cluster (aptly, backups, etc.) goes
through here.

## Image

`registry.munchbox.cc/s3-orchestrator:v0.139.1`

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
- Vault paths `secret/data/edge-proxy/{b2,ibm,oci}` for the keypairs it
  signs with when reaching those three through their edge proxies

## Edge proxies (b2 / ibm / oci)

Backblaze, IBM and Oracle do not bill egress on traffic leaving to
Cloudflare. So those three backends point at
`https://{b2,ibm,oci}-proxy.munchbox.cc` rather than the provider
endpoint, and their reads cost nothing. Measured on b2: 1,679 MB read in
a day, of which Backblaze counted 42 MB.

Each proxy is a Cloudflare Worker, deployed by terragrunt from
`dns/cloudflare/edge-proxy`. The script is built in the s3-orchestrator
repo and published to the `artifacts` bucket at a pinned version, which
terragrunt reads back. Cloudflare runs JavaScript and the worker is
TypeScript, so it has to be bundled before terraform can upload it.

Three things to know before changing any of this:

- This job does not hold those backends' real credentials. It signs with
  the `edge-proxy/*` keypair; the worker checks that, then re-signs to
  the provider with the real keys, which live only in Cloudflare. A plain
  CNAME cannot replace the worker, because SigV4 signs the hostname and
  the provider rejects anything addressed to the proxy.
- All three need `strip_sdk_headers: true`. The Go SDK signs
  `accept-encoding`, Cloudflare rewrites it in transit, and the worker
  checks the signature against what arrived. Without the flag every
  request fails with `SignatureDoesNotMatch`.
- The proxy hostnames need their own Pi-hole records (see
  `pihole_special_dns_records`). The internal `*.munchbox.cc` wildcard
  would otherwise answer them with traefik, and traffic that never
  reaches Cloudflare gets neither the worker nor the free egress.

Egress budgets on these three are `0`, meaning unlimited, since the
allowance they used to track no longer applies. Request budgets stay as
they were: only egress is waived.

## Notable configuration

- Vault role `s3-orchestrator`: its own prefix plus the four
  `s3-bucket/*` keys, the three `edge-proxy/*` keypairs, and transit
- Routing strategy `spread`; replication factor 2
- Per-backend `disable_checksum` / `unsigned_payload` /
  `strip_sdk_headers` flags for GCS and e2 compatibility
- Backend circuit breaker: 3 failures, 30m open; cluster CB: 3
  failures, 1200s open, parallel broadcast on degraded
- Integrity scrubber every 24h; rebalance every 24h; pending-write
  reaper every 10m
- Rate limit 1500 rps / 2000 burst with RFC1918 trusted proxies
