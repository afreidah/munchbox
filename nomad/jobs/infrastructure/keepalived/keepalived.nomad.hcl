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
        image        = "alpine:3.21"
        network_mode = "host"

        # Required for VRRP and VIP management
        privileged = true
        cap_add    = ["NET_ADMIN", "NET_RAW"]

        entrypoint = ["/bin/sh", "-c"]
        args       = ["apk add --no-cache keepalived curl > /dev/null 2>&1 && exec keepalived -f /etc/keepalived/keepalived.conf --dont-fork --log-console"]

        volumes = [
          "local/keepalived.conf:/etc/keepalived/keepalived.conf:ro",
          "local/check_traefik.sh:/etc/keepalived/check_traefik.sh:ro"
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
        EOF
      }

      # --- Health Check Script ---
      template {
        destination = "local/check_traefik.sh"
        perms       = "0755"
        change_mode = "restart"
        data        = <<-EOF
#!/bin/sh
# Check if Traefik is responding on the local node
curl -sf http://127.0.0.1:8081/ping > /dev/null 2>&1
exit $?
        EOF
      }

      resources {
        cpu    = 50
        memory = 64
      }

      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
