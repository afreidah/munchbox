# cloudflaresolver

Byparr headless-browser proxy that solves Cloudflare anti-bot challenges on
behalf of Prowlarr / *arr indexers. Drop-in FlareSolverr replacement, kept under
the same Consul service name so Prowlarr needs no config change.

## image

`ghcr.io/thephaseless/byparr:2.1.0`

Replaced `ghcr.io/flaresolverr/flaresolverr` (abandoned upstream, unpatched
CVEs). Byparr is actively maintained and exposes the same FlareSolverr `/v1` API
on the same port, so Prowlarr's existing proxy config is unchanged.

## job type

Raw Nomad job (`.nomad.hcl`), not a munchbox-service pack job -- Byparr needs a
`shm_size` bump the pack can't express.

## hostname / exposure

- internal-only, no Traefik route
- registered in Consul as `cloudflaresolverr` on static port `8191`
- consumers reach it via Consul DNS / service discovery

## placement

- constraint: `meta.gpu = true`
- pinned to the GPU node (nomad-client-04) alongside the rest of the media
  stack, not for GPU use but to co-locate with Prowlarr / Sonarr / Radarr
- `network_mode = host`, single instance

## dependencies

- none -- standalone headless Chromium
- consumed by Prowlarr (and downstream *arr apps) for indexer scrapes

## notable configuration

- `shm_size = 512 MiB` -- Chromium crashes on Docker's default 64 MiB; tmpfs, so
  it costs nothing until a challenge is actively being solved
- `memory = 256` reservation with `memory_max = 1536` burst -- cluster memory
  oversubscription lets it idle cheap and only balloon while solving, instead of
  pinning a full gig it almost never uses
- `TZ=America/Los_Angeles`, `LOG_LEVEL=info`
- ephemeral; no persistent cookie/cache state
