# registry

Internal Docker Registry v2 for storing and distributing container images
within the cluster, plus a read-only web UI for browsing repositories. Two
jobs: `registry` (server) and `registry-ui` (web frontend).

## Image

- registry: `registry:3`
- registry-ui: `joxit/docker-registry-ui@sha256:9e561fbe...` (pinned digest)

## Hostname / exposure

- `registry.munchbox.cc` (registry, port 5000, host-networked)
- `registry-ui.munchbox.cc` (UI, gated by `oauth2-proxy@file`)
- Both have HTTP routers for Cloudflare tunnel ingress

## Placement

- registry: pinned to `stabler` (`node = "stabler"`) because of the gdrive
  volume mount
- registry-ui: no constraint

## Dependencies

- Host volume `/mnt/gdrive/munchbox-data/registry` (image blobs)
- Tempo for OTLP traces (`tempo.service.consul:4318`)
- UI proxies to the registry by IP (`http://192.168.68.61:5000`)

## Notable configuration

- Args `serve /local/config.yml` with config templated from
  `files/registry-config.yml`
- Registry health probe `/v2/`
- UI is read-only (`DELETE_IMAGES = "false"`)
