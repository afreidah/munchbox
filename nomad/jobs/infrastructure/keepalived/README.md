# keepalived

VRRP-based virtual IP failover for ingress HA. Two VIPs:

- `192.168.68.50` -- Traefik VIP; all `*.munchbox.cc` DNS points here
- `192.168.68.49` -- WireGuard VIP; floats to whichever ingress node has a
  healthy `wg0` peer

System job on ingress-role nodes, active/passive with goren as MASTER.

## Image

`alpine:3.21.7` (keepalived, curl, wireguard-tools installed at task start)

## Hostname / exposure

- Internal-only Consul service `keepalived` (`traefik.enable=false`)
- VIPs are layer-2 (gratuitous ARP); no service port

## Placement

- System job, `constraint meta.role = ingress`
- Priority 95 so it starts before most services
- MASTER on `goren` (priority 101), BACKUP on `nomad-client-05` (priority 100)
- VRRP interface taken from `meta.vrrp_interface` per node

## Dependencies

- Traefik on `127.0.0.1:8081/ping` (track script for VI_TRAEFIK)
- WireGuard `wg0` interface with a recent peer handshake (<180s) for
  VI_WIREGUARD

## Notable configuration

- `check_traefik.sh` weights `-50` on 3 consecutive failures, `rise 2`
- `check_wireguard.sh` checks `wg show wg0 latest-handshakes` -- distinguishes
  "service up" from "actually exchanging traffic"
- VI_WIREGUARD intentionally does NOT use `use_vmac`: home router (TP-Link
  Deco) binds the port-forward to goren's MAC+IP, so failover to
  nomad-client-05 currently requires a manual Deco reconfig
- Privileged container with `NET_ADMIN` / `NET_RAW`, host networking
