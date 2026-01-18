# -------------------------------------------------------------------------------
# Keepalived — VRRP-based Virtual IP Failover for Traefik HA
#
# Project: Munchbox / Author: Alex Freidah
#
# Provides active-active load distribution with automatic failover using dual
# VIPs. Each ingress node is primary for one VIP and backup for the other.
# Health checks monitor Traefik to trigger failover on service failure.
#
# VIP1: 192.168.68.50 (stabler primary, goren backup)
# VIP2: 192.168.68.51 (goren primary, stabler backup)
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
        image        = "osixia/keepalived:2.0.20"
        network_mode = "host"

        # Required for VRRP and VIP management
        privileged = true
        cap_add    = ["NET_ADMIN", "NET_BROADCAST", "NET_RAW"]

        volumes = [
          "local/keepalived.conf:/container/service/keepalived/assets/keepalived.conf:ro",
          "local/check_traefik.sh:/etc/keepalived/check_traefik.sh:ro"
        ]
      }

      env {
        KEEPALIVED_INTERFACE = "eth0"
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

# VIP1: 192.168.68.50 (stabler primary)
vrrp_instance VI_1 {
  state {{ if eq (env "node.unique.name") "stabler.munchbox.cc" }}MASTER{{ else }}BACKUP{{ end }}
  interface eth0
  virtual_router_id 50
  priority {{ if eq (env "node.unique.name") "stabler.munchbox.cc" }}101{{ else }}100{{ end }}
  advert_int 1
  nopreempt

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

# VIP2: 192.168.68.51 (goren primary)
vrrp_instance VI_2 {
  state {{ if eq (env "node.unique.name") "goren" }}MASTER{{ else }}BACKUP{{ end }}
  interface eth0
  virtual_router_id 51
  priority {{ if eq (env "node.unique.name") "goren" }}101{{ else }}100{{ end }}
  advert_int 1
  nopreempt

  authentication {
    auth_type PASS
    auth_pass munchbox51
  }

  virtual_ipaddress {
    192.168.68.51/24
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
        memory = 32
      }

      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
