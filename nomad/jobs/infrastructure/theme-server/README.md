# theme-server

Static HTTP server for custom Catppuccin Mocha CSS overrides consumed by the
*arr stack, Deluge, and other apps that support external CSS injection via
theme.park.

## Image

`registry.munchbox.cc/theme-server:latest`

## Hostname / exposure

- `themes.munchbox.cc`
- HTTPS router (default Traefik wiring)
- Extra HTTP router on the `web` entrypoint so containers can fetch CSS without
  TLS

## Placement

- Constraint: `meta.cloud = oracle`
- Runs on the larger Oracle nodes; host-networked on static port 8078

## Dependencies

- None (no DB, no Vault, no upstream services)
- Consumed by: sonarr, radarr, lidarr, prowlarr, readarr, deluge

## Notable configuration

- Static port 8078, `host_network = true`
- `/health` endpoint for Nomad checks
- Image is built locally and pushed to the internal registry
