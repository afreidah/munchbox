# jellyfin

Open-source media server with hardware-accelerated transcoding and Live TV.
Runs alongside Emby (Emby still owns ErsatzTV/Live TV duty).

## Image

`jellyfin/jellyfin:10.11.10`

## Hostname / exposure

- `jellyfin.munchbox.cc`
- HTTPS router on `websecure` with `letsencrypt` and `jellyfin-ratelimit@file`
- HTTP router on `web` for Cloudflare tunnel (same ratelimit middleware)
- No oauth2-proxy: Jellyfin uses its own user auth
- Host-networked on 8096 (HTTP) and extra static 8920 (HTTPS)

## Placement

- Constraint: `meta.gpu = true`
- Pinned to the GPU-passthrough media node for NVENC transcoding

## Dependencies

- NVIDIA runtime; passes `/dev/nvidia0`, `nvidiactl`, `nvidia-uvm`,
  `nvidia-uvm-tools`
- Host volumes: `/opt/nomad/data/jellyfin/{config,cache}`,
  `/tank/media/{Movies,TV,Music}` mounted read-only

## Notable configuration

- 3500 MHz / 4 GiB reservation
- `JELLYFIN_PublishedServerUrl = https://jellyfin.munchbox.cc`
- Health probe `/System/Ping`
- 30s kill timeout, SIGTERM
