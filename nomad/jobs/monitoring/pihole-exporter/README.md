# pihole-exporter

Single `ekofr/pihole-exporter` instance scraping both Pi-hole nodes (green
and logan) via comma-separated `PIHOLE_HOSTNAME`. Replaces the on-Pi
binaries that ansible installed and that Pi-hole v6 broke (armv6 vs
GOARM=7 + v6 REST API rewrite).

## Image

`ekofr/pihole-exporter:v1.2.0`

## Hostname / exposure

- Internal-only; `traefik = false`
- Prometheus scrapes `/metrics` on static port 9617

## Placement

- Constraint: `meta.cloud != oracle`
- Lives on-prem so probes ride the LAN rather than the WireGuard tunnel

## Dependencies

- Pi-holes at `192.168.68.62,192.168.68.64` (PIHOLE_HOSTNAME accepts CSV;
  exporter scrapes both)
- Vault `secret/pihole/green` (both Pi-holes share the password after the
  post-takeover rotation), rendered into `secrets/pihole.env` as env vars

## Notable configuration

- Health check `/metrics` with 10s timeout, 30s interval -- ekofr's
  exporter scrapes Pi-hole synchronously on each hit (~3s per call)
- Tiny resource size, 64 MiB
