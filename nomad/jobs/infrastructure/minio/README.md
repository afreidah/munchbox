# minio

Two MinIO instances in single-drive mode on the OCI ARM nodes, each
backed by its own 80 GB OCI block volume at `/mnt/minio-data`. These
back the `minio` and `minio-arm2` backends in s3-orchestrator, giving
the cluster roughly 140 GiB of free-tier S3-compatible capacity that
lives outside the homelab.

## Image

`minio/minio:latest`

## Hostname / exposure

- API: registered as `minio` (round-robin) and per-node
  `minio-<node>` services on port 9010; no traefik on the API
- Console: per-node `minio-console-<node>` at
  `minio-<node>.munchbox.cc` through `oauth2-proxy@file`, with the
  `cf-tunnel-https@file` variant for the Cloudflare tunnel path

## Placement

- `node_pool = oracle`, constrained to `^oraclearm[12]$`
- `distinct_hosts = true` + spread so each alloc lands on its own
  block volume

## Dependencies

- Host volume `/mnt/minio-data` (one OCI block volume per node)
- Vault path `secret/data/minio` for `root_user` / `root_password`

## Notable configuration

- Host network, static ports 9010 (API) and 9011 (console)
- Single-drive `server /data` mode -- no erasure coding
- Consumed by s3-orchestrator as the `minio` and `minio-arm2`
  backends, each with a 70 GiB quota
