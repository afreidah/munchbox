# Keepalived

VRRP-based virtual IP failover for Traefik high availability. Runs as a
system job on ingress-role nodes, providing a single VIP (192.168.68.50)
with active-passive failover.

## Architecture

One ingress node (goren) runs as VRRP MASTER with priority 101, the
other (nomad-client-05) as BACKUP with priority 100. A health check
script curls the local Traefik ping endpoint every two seconds. If
Traefik becomes unresponsive after three consecutive failures, the
check weight drops the node's priority, causing the backup to assume
the VIP within approximately six seconds. The `nopreempt` flag prevents
flapping when a recovered node rejoins.

All DNS records point to the single VIP. During a failure, the backup
node claims the VIP via gratuitous ARP and serves all traffic until
the primary recovers.

## Notable Configuration

- System job constrained to `meta.role = "ingress"` nodes
- Uses `alpine:3.21` with keepalived installed at runtime for multi-arch
  support (goren is ARM64)
- Privileged container with NET_ADMIN/NET_RAW capabilities for VIP management
- VRRP interface configured per-node via `meta.vrrp_interface`
- Priority 95 ensures keepalived starts before most other services

## Dependencies

- **Traefik** -- health check target; keepalived has no purpose without it
