# aptly-s3-gateway

SigV4-signing reverse proxy that lets stock apt clients fetch the
S3-backed publish tree (dists/, pool/) from s3-orchestrator. Runs
nginx-s3-gateway in its own job so its nginx and aptly's bundled
nginx don't collide on port 80 inside a shared alloc network.

## Image

`nginxinc/nginx-s3-gateway:latest-njs-oss`

## Hostname / exposure

- `apt.munchbox.cc` with `PathPrefix(/dists/)` and `PathPrefix(/pool/)`
- HTTPS routers on websecure, plus HTTP routers via `cf-tunnel-https@file`
  for the Cloudflare tunnel path
- Higher priority (100) than the catch-all aptly route, so apt clients
  hit the gateway directly rather than aptly's nginx

## Placement

- amd64 only (`attr.cpu.arch = amd64`) -- the njs-oss image is amd64-only
- `node_pool = all`, single instance

## Dependencies

- s3-orchestrator at `s3-orchestrator.service.consul:9000` (bucket `aptly`)
- Vault path `secret/data/aptly` for `s3_access_key` / `s3_secret_key`
  used to SigV4-sign upstream requests

## Notable configuration

- Static port 8092 mapped to container :80
- `AWS_SIGS_VERSION = 4`, `S3_STYLE = path`
- `ALLOW_DIRECTORY_LIST = true` so apt can walk the tree
- Cache TTLs: 1h on 200, 1m on 404, 30s on 403
- `dists/` (repo metadata) is served straight from S3, never cached
  (`zz-apt-metadata-nocache.conf` drop-in). InRelease pins exact hashes of
  Packages, and independent per-object cache expiry serves a fresh InRelease
  against a stale Packages -> apt `File has unexpected size` errors right after
  a publish. Only `pool/*.deb` (immutable) stays cached.
