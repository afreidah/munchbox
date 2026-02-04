# Keepalived

VRRP-based virtual IP failover for Traefik high availability. Runs as a
system job on ingress-role nodes, providing two VIPs with active-active
load distribution.

## Architecture

Each ingress node is primary for one VIP and backup for the other. A
VRRP health check script curls the local Traefik ping endpoint every two
seconds. If Traefik becomes unresponsive, the check weight drops the
node's priority, causing the backup to assume the VIP within seconds.
The `nopreempt` flag prevents flapping when a recovered node rejoins.

DNS points to both VIPs, so under normal operation traffic distributes
across both ingress nodes. During a failure, one node holds both VIPs
until the other recovers.

## Notable Configuration

- System job type ensures one instance per ingress node automatically
- Privileged container with NET_ADMIN/NET_RAW capabilities for VIP management
- Priority 95 ensures keepalived starts before most other services

## Dependencies

- **Traefik** -- health check target; keepalived has no purpose without it
