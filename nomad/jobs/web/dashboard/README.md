# dashboard

Hugo-Dash static dashboard served through NGINX. Central landing page with
links to operational web interfaces across the cluster (Nomad, Consul,
Grafana, Proxmox, etc.). Site config lives in `src/dashboard/data/config.yaml`.

## Image

`registry.munchbox.cc/dash:latest`

## Hostname / exposure

- `dashboard.munchbox.cc`
- HTTPS router with `letsencrypt` certresolver, gated by `oauth2-proxy@file`
- HTTP router for Cloudflare tunnel, same oauth chain

## Placement

- Constraint: `meta.cloud != oracle`
- Home cluster only; CF-tunnel + oauth2-proxy browser flow returns 502 when
  this lands behind WG on an Oracle node (single curl works, browser auth
  loop does not)

## Dependencies

- oauth2-proxy (forward auth)
- Internal Docker registry for the image

## Notable configuration

- Tiny resource size: 50 MHz / 32 MiB, ephemeral storage
- Health probe `/`
- Image built from `src/dashboard/` and pushed to `registry.munchbox.cc/dash`
