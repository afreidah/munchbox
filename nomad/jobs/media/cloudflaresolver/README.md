# cloudflaresolver

FlareSolverr headless-browser proxy that solves Cloudflare anti-bot challenges
on behalf of Prowlarr / *arr indexers.

## image

`ghcr.io/flaresolverr/flaresolverr:v3.4.6`

## hostname / exposure

- internal-only, `traefik = false`
- registered in Consul as `cloudflaresolverr` on static port `8191`
- consumers reach it via Consul DNS / service discovery

## placement

- constraint: `meta.gpu = true`
- pinned to the GPU node (nomad-client-04) alongside the rest of the media
  stack, not for GPU use but to co-locate with Prowlarr / Sonarr / Radarr
- `host_network = true`, single instance

## dependencies

- none -- standalone headless Chromium
- consumed by Prowlarr (and downstream *arr apps) for indexer scrapes

## notable configuration

- size `medium`, 512 MiB memory (headless Chromium is the heavy bit)
- `TZ=America/Los_Angeles`, `LOG_LEVEL=info`
- ephemeral storage; no persistent cookie/cache state
