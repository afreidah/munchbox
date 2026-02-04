# Deluge

BitTorrent client with all traffic routed through a Mullvad VPN tunnel via
gluetun sidecar. The bridge networking model ensures torrent traffic never
touches the home IP address, and gluetun's built-in iptables kill switch
blocks all non-VPN internet traffic if the tunnel drops.

## Architecture

Two-task group in bridge networking mode. Gluetun runs as a prestart sidecar
and establishes the VPN tunnel before Deluge starts. Deluge shares gluetun's
network namespace via bridge mode, so all its traffic routes through the VPN
automatically. Port mappings are defined at the group level and forwarded
through gluetun's network stack.

## Components

| Task | Role | Lifecycle |
|------|------|-----------|
| gluetun | Mullvad OpenVPN tunnel, exposes ports for Deluge | prestart sidecar |
| deluge | BitTorrent client using gluetun's network | main |

## Data Flow

Inbound/outbound torrent traffic flows through the Mullvad VPN endpoint.
Web UI traffic enters via Traefik on port 8112, which maps through the
bridge network to gluetun's exposed port. LAN subnets (192.168.68.0/24 and
10.200.0.0/24) are whitelisted in gluetun's firewall for web UI and local
service access. Downloaded files land on /tank via bind mount.

## Failure Modes

- **VPN tunnel drop**: gluetun's iptables rules immediately block all
  internet traffic. The `vpn-tunnel` health check polls gluetun's status API
  every 30s and triggers a full group restart after 3 consecutive failures
  (90s grace period).
- **Mullvad credential rotation**: Update the Vault secret at
  `secret/data/mullvad` and restart the job.

## Dependencies

**Requires:**
- Vault (Mullvad credentials, Deluge web UI password hash)

**Required by:**
- Sonarr, Radarr, Lidarr, Readarr, Prowlarr (download client)

## Notable Configuration

- Gluetun runs privileged with NET_ADMIN capability and /dev/net/tun access
  for VPN tunnel creation
- OPENVPN_ENDPOINT_IP is hardcoded to avoid DNS resolution issues during VPN
  tunnel bootstrap
- Pinned to nomad-client-04 for /tank ZFS pool access
