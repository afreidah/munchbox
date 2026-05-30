# deluge

BitTorrent client with all traffic routed through a Mullvad WireGuard tunnel
via a gluetun sidecar. Bridge networking ensures torrent traffic never sees
the home IP, and gluetun's iptables kill switch drops non-VPN traffic if the
tunnel goes down.

## Image

- gluetun: `qmcgaw/gluetun:v3.41.0`
- deluge: `linuxserver/deluge:2.2.0`
- cleanup-vpn: `alpine:3.21`

## Hostname / exposure

- `deluge.munchbox.cc`
- HTTPS + HTTP routers via Traefik, both gated by `oauth2-proxy@file`
- Service `deluge` advertised at node IP, port 8112 (mapped through bridge
  via gluetun)

## Placement

- Constraint: `meta.gpu = true` (pin to GPU node for `/tank` access alongside
  the rest of the media stack)
- Bridge networking; static ports 8112 (web), 6881 (torrent), 8000 (gluetun
  control)

## Dependencies

- Vault `secret/data/mullvad` (WireGuard private key, address) and
  `secret/data/deluge` (web UI pwd salt + sha1)
- Host volumes: `/opt/nomad/data/deluge` -> `/config`, `/tank` -> `/data`
- theme.park `catppuccin-mocha` via DOCKER_MODS

## Notable configuration

- gluetun: `VPN_SERVICE_PROVIDER=mullvad`, `VPN_TYPE=wireguard` (OpenVPN
  certs expired -- WG path)
- `SERVER_CITIES=Los Angeles CA`,
  `FIREWALL_OUTBOUND_SUBNETS=192.168.68.0/24,10.200.0.0/24`,
  `HTTP_CONTROL_SERVER_ADDRESS=:8000`
- `vpn-tunnel` HTTP check on gluetun `/v1/vpn/status`; `check_restart` of 3
  with 90s grace forces a full group restart on tunnel loss
- Prestart `cleanup-vpn` (alpine, privileged, host net) deletes stale `tun0`
  / `wg0` interfaces from a dirty exit
- gluetun runs privileged with NET_ADMIN and `/dev/net/tun`
