# -------------------------------------------------------------------------------
# WireGuard Server - Ingress-Side Active/Passive WG Hub
#
# Project: Munchbox / Author: Alex Freidah
#
# Runs the home-side WireGuard server on every ingress node simultaneously,
# all sharing the same private key from Vault. Only the ingress node holding
# the VI_WIREGUARD VIP (managed by the keepalived job) actually receives
# inbound traffic because the home router port-forwards 51820/udp to that
# VIP. Failover is transparent: the VIP moves and Oracle peers re-handshake
# on their next PersistentKeepalive tick.
#
# Both nodes run WG continuously rather than starting/stopping on VRRP state
# changes, which removes any race during failover. The shared private key
# means peers see a single identity regardless of which node currently
# answers.
# -------------------------------------------------------------------------------

job "wireguard-server" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 95

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
    tier       = "tier-0"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "1m"
  }

  # ---------------------------------------------------------------------------
  # Placement - Ingress nodes only
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Task Group: wireguard-server
  # ---------------------------------------------------------------------------

  group "wireguard-server" {

    network {
      mode = "host"
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service Registration ---
    service {
      name     = "wireguard-server"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "infrastructure",
        "wireguard",
        "ha"
      ]

      check {
        name     = "wg-handshake"
        type     = "script"
        task     = "wireguard"
        command  = "/bin/sh"
        args     = ["-c", "wg show wg0 latest-handshakes 2>/dev/null | awk -v now=$(date +%s) '{ if ($2 > 0 && (now - $2) < 180) found=1 } END { exit !found }'"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: wireguard
    # -------------------------------------------------------------------------

    task "wireguard" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "alpine:3.21"
        network_mode = "host"

        # NET_ADMIN + NET_RAW let wg-quick manage the wg0 interface via
        # netlink and install the NAT/forward iptables rules in PostUp.
        # SYS_MODULE would be needed only if the container itself had to
        # modprobe the wireguard module - the host loads it via the
        # wireguard-ingress-prereqs playbook so the container does not.
        privileged = true
        cap_add    = ["NET_ADMIN", "NET_RAW"]

        entrypoint = ["/bin/sh", "-c"]
        args = [
          "apk add --no-cache wireguard-tools iptables > /dev/null 2>&1 && exec /local/run.sh"
        ]

        volumes = [
          "secrets/wg0.conf:/etc/wireguard/wg0.conf:ro",
          "local/run.sh:/local/run.sh:ro",
        ]
      }

      # --- Run script: brings the interface up and parks until killed ---
      # wg-quick needs to run inside the container with NET_ADMIN to create
      # wg0 in the host network namespace; trap SIGTERM so the interface is
      # torn down cleanly on alloc stop instead of leaving a stale wg0.
      template {
        destination = "local/run.sh"
        perms       = "0755"
        change_mode = "restart"
        data        = <<-EOF
#!/bin/sh
set -e

cleanup() {
  wg-quick down wg0 2>/dev/null || true
  exit 0
}
trap cleanup TERM INT

# Tear down any leftover interface from a previous incarnation.
ip link show wg0 >/dev/null 2>&1 && wg-quick down wg0 || true

wg-quick up wg0
echo "wireguard interface up: $(wg show wg0 listen-port)"

# Park forever; restart loop is owned by Nomad.
while true; do sleep 60 & wait $!; done
        EOF
      }

      # --- WireGuard Configuration ---
      # Only the server private key is sourced from Vault. Peer public
      # keys are not secrets and live inline so the configuration is fully
      # auditable from git. The inline values must match
      # infrastructure/ansible/inventory/group_vars/wireguard_server.yml -
      # both files describe the same set of remote peers, just for two
      # different server-side runtimes (this Nomad job on ingress vs the
      # legacy Ansible role on stabler).
      template {
        destination = "secrets/wg0.conf"
        perms       = "0600"
        change_mode = "restart"
        data        = <<-EOF
[Interface]
Address = 10.200.0.1/24
ListenPort = 51820
PrivateKey = {{ with secret "secret/data/wireguard" }}{{ .Data.data.server_private_key }}{{ end }}

PostUp = iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o eth0 -j MASQUERADE
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s 10.200.0.0/24 -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
# oracle-node-1
PublicKey = ikphBrH+hLuYIqpMpoZOAPoPHaXXrMy5d3LSKjLVcnE=
AllowedIPs = 10.200.0.11/32
PersistentKeepalive = 25

[Peer]
# oracle-node-2
PublicKey = ox0qRomZZlhl9yHpYgzhWvh+taXGIeUhc+MYSSnLmx4=
AllowedIPs = 10.200.0.12/32
PersistentKeepalive = 25

[Peer]
# oracle-arm-1
PublicKey = ifDrDLx7PaCcPiNJVH9DSHJ2hNwDper5pOr+jVZKw0A=
AllowedIPs = 10.200.0.13/32
PersistentKeepalive = 25

[Peer]
# oracle-arm-2
PublicKey = tit5mdLQ+7SWWTmEUDxKsy6GPTHu4B2uvo9fwqQ7uDs=
AllowedIPs = 10.200.0.14/32
PersistentKeepalive = 25
        EOF
      }

      resources {
        cpu    = 50
        memory = 128
      }

      kill_timeout = "15s"
      kill_signal  = "SIGTERM"
    }
  }
}
