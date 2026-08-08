# -------------------------------------------------------------------------------
# Keepalived — VRRP-based Virtual IP Failover for Traefik HA
#
# Project: Munchbox / Author: Alex Freidah
#
# Active-passive failover with a single VIP. goren is the primary ingress node;
# nomad-client-05 is the standby. Health checks monitor Traefik to trigger
# automatic failover on service failure.
#
# VIP: 192.168.68.50 (goren primary, nomad-client-05 backup)
# -------------------------------------------------------------------------------

job "keepalived" {
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
    min_healthy_time = "10s"
    healthy_deadline = "2m"
    auto_revert      = true
    stagger          = "30s"
  }

  # ---------------------------------------------------------------------------
  # Placement — Run on ingress nodes only
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "${meta.role}"
    operator  = "="
    value     = "ingress"
  }

  # ---------------------------------------------------------------------------
  # Task Group: keepalived
  # ---------------------------------------------------------------------------

  group "keepalived" {

    network {
      mode = "host"
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "10s"
      mode     = "fail"
    }

    # --- Service Registration ---
    service {
      name     = "keepalived"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "infrastructure",
        "vrrp",
        "ha"
      ]
    }

    # -------------------------------------------------------------------------
    # Task: keepalived
    # -------------------------------------------------------------------------

    task "keepalived" {
      driver = "docker"

      config {
        image        = "alpine:3.23.5"
        network_mode = "host"

        # Required for VRRP and VIP management
        privileged = true
        cap_add    = ["NET_ADMIN", "NET_RAW"]

        entrypoint = ["/bin/sh", "-c"]
        args       = ["apk add --no-cache keepalived curl wireguard-tools > /dev/null 2>&1 && exec keepalived -f /etc/keepalived/keepalived.conf --dont-fork --log-console"]

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro",
          "local/check_traefik.sh:/etc/keepalived/check_traefik.sh:ro",
          "local/check_wireguard.sh:/etc/keepalived/check_wireguard.sh:ro",
        ]
      }

      # --- Keepalived Configuration ---
      template {
        destination = "local/keepalived.conf"
        change_mode = "restart"
        data        = <<-EOF
! Keepalived Configuration for Traefik HA
! Node: {{ env "node.unique.name" }}

global_defs {
  router_id {{ env "node.unique.name" }}
  script_user root
  enable_script_security
}

# Health check script for Traefik
vrrp_script check_traefik {
  script "/etc/keepalived/check_traefik.sh"
  interval 2
  timeout 3
  weight -50
  fall 3
  rise 2
}

# Health check script for WireGuard server liveness
vrrp_script check_wireguard {
  script "/etc/keepalived/check_wireguard.sh"
  interval 5
  timeout 4
  weight -50
  fall 3
  rise 2
}

# VIP: 192.168.68.50 (goren primary, nomad-client-05 backup)
vrrp_instance VI_TRAEFIK {
  state {{ if eq (env "node.unique.name") "goren" }}MASTER{{ else }}BACKUP{{ end }}
  interface {{ env "meta.vrrp_interface" }}
  virtual_router_id 50
  priority {{ if eq (env "node.unique.name") "goren" }}101{{ else }}100{{ end }}
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass munchbox50
  }

  virtual_ipaddress {
    192.168.68.50/24
  }

  track_script {
    check_traefik
  }
}

# VIP: 192.168.68.49 (goren primary, nomad-client-05 backup)
# Floats to whichever ingress node currently has a healthy WireGuard
# interface. The home router (TP-Link Deco) binds port-forwards to
# MAC+IP, and use_vmac (RFC 5798 virtual MAC) tripped Deco's mesh ARP
# bridging across wired/wifi segments. Reverted to plain VIP without
# use_vmac; the port-forward is bound to goren's MAC + .49, so failover
# to nomad-client-05 currently requires a manual Deco reconfig. Tracked
# as a separate hardening item.
vrrp_instance VI_WIREGUARD {
  state {{ if eq (env "node.unique.name") "goren" }}MASTER{{ else }}BACKUP{{ end }}
  interface {{ env "meta.vrrp_interface" }}
  virtual_router_id 49
  priority {{ if eq (env "node.unique.name") "goren" }}101{{ else }}100{{ end }}
  advert_int 1

  authentication {
    auth_type PASS
    auth_pass munchbox49
  }

  virtual_ipaddress {
    192.168.68.49/24
  }

  track_script {
    check_wireguard
  }
}
        EOF
      }

      # --- Health Check Script: Traefik ---
      template {
        destination = "local/check_traefik.sh"
        perms       = "0755"
        change_mode = "restart"
        data        = <<-EOF
#!/bin/sh
# The VIP must follow whether THIS node can actually serve authenticated
# ingress, not merely whether keepalived is alive. Each probe is hard-bounded
# with --max-time so a HUNG component (I/O-wedged node, stuck Traefik) fails
# the check instead of blocking forever -- that hang-vs-fail gap is why a
# wedged goren held MASTER on 2026-08-08. Traefik data plane AND the local
# oauth2-proxy forward-auth both have to answer.
curl -sf --max-time 2 http://127.0.0.1:8081/ping > /dev/null 2>&1 || exit 1
curl -sf --max-time 2 http://127.0.0.1:4180/ping > /dev/null 2>&1 || exit 1
exit 0
        EOF
      }

      # --- Health Check Script: WireGuard ---
      # Healthy when wg0 exists AND at least one peer has handshaken in the
      # last 180 seconds. The handshake check distinguishes "WG service is
      # running" from "WG service is actually exchanging traffic" - the
      # latter is what callers care about.
      template {
        destination = "local/check_wireguard.sh"
        perms       = "0755"
        change_mode = "restart"
        data        = <<-EOF
#!/bin/sh
ip link show wg0 >/dev/null 2>&1 || exit 1
wg show wg0 latest-handshakes 2>/dev/null \
  | awk -v now=$(date +%s) '{ if ($2 > 0 && (now - $2) < 180) found=1 } END { exit !found }'
        EOF
      }

      resources {
        cpu    = 150
        memory = 64
      }

      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
