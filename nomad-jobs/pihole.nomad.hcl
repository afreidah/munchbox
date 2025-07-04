# Pi-hole — Nomad Job (with persistent volumes under /opt/nomad/data)
#
# - Runs Pi-hole using official Docker image
# - Persists both /etc/pihole and /etc/dnsmasq.d on the host at /opt/nomad/data/…
# - Registers with Consul for service discovery
# - Routes through Traefik at https://pihole.lan
# - Uses host networking (required for DNS/DHCP)
# - Binds HTTP on port 80 to avoid conflict with Traefik on port 80
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# 1) Make sure your Nomad client has this in /etc/nomad.d/client.hcl:
#
# client {
#   host_volume "pihole-config" {
#     path      = "/opt/nomad/data/pihole/etc-pihole"
#     read_only = false
#   }
#   host_volume "pihole-dnsmasq" {
#     path      = "/opt/nomad/data/pihole/dnsmasq.d"
#     read_only = false
#   }
# }
#
# Then `sudo systemctl restart nomad` on each Pi.
# -------------------------------------------------------------------------------

job "pihole" {
  datacenters = ["pi-dc"]   # --- Only run in the pi-dc datacenter ---
  type        = "service"   # --- Service job, managed by Nomad ---

  meta {
    run_uuid = "${uuidv4()}" # --- Unique run identifier for traceability ---
  }

  group "pihole" {
    count = 1

    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "pi5"      # --- Only run on nodes with class "pi5" ---
    }

    # ---------------------------------------------------------------------------
    # Attach the two host_volumes declared in client.hcl for persistent storage
    # ---------------------------------------------------------------------------
    volume "config" {
      type      = "host"
      source    = "pihole-config"
      read_only = false
    }

    volume "dnsmasq" {
      type      = "host"
      source    = "pihole-dnsmasq"
      read_only = false
    }

    # ---------------------------------------------------------------------------
    # Host networking for full control over ports (required for DNS/DHCP)
    # ---------------------------------------------------------------------------
    network {
      mode = "host"
      port "dns"   { static = 53  }   # --- DNS port ---
      port "dhcp"  { static = 67  }   # --- DHCP port ---
      port "https" { static = 443 }   # --- HTTPS for admin UI (optional) ---
      port "http"  { static = 80  }   # --- HTTP for admin UI ---
    }

    # ---------------------------------------------------------------------------
    # Pi-hole Task: runs the Pi-hole container and registers with Consul/Traefik
    # ---------------------------------------------------------------------------
    task "pihole" {
      driver = "docker"

      # -------------------------------------------------------------------------
      # Register Pi-hole in Consul (with Traefik tags for routing)
      # -------------------------------------------------------------------------
      service {
        name     = "pihole"
        port     = "http"         # --- matches network.port "http" ---
        provider = "consul"

        tags = [
          "traefik.enable=true",                                        # --- Enable Traefik ---
          "traefik.http.routers.pihole.rule=Host(`pihole.lan`)",        # --- Traefik routing rule ---
          "traefik.http.routers.pihole.entrypoints=traefik",            # --- Traefik entrypoint ---
          "traefik.http.services.pihole.loadbalancer.server.port=80"    # --- Internal service port for Traefik ---
        ]

        check {
          name     = "pihole-tcp"
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # -------------------------------------------------------------------------
      # Mount persistent volumes for Pi-hole and dnsmasq configuration
      # -------------------------------------------------------------------------
      volume_mount {
        volume      = "config"
        destination = "/etc/pihole"
        read_only   = false
      }

      volume_mount {
        volume      = "dnsmasq"
        destination = "/etc/dnsmasq.d"
        read_only   = false
      }

      # -------------------------------------------------------------------------
      # Docker container configuration
      # -------------------------------------------------------------------------
      config {
        image              = "pihole/pihole:latest"
        network_mode       = "host"
        privileged         = true
        image_pull_timeout = "10m"
        ports              = ["dns", "dhcp", "http", "https"]
      }

      # -------------------------------------------------------------------------
      # Environment variables for Pi-hole configuration
      # -------------------------------------------------------------------------
      env = {
        PIHOLE_DNSMASQ_LISTENING        = "all"
        PIHOLE_DNS_1                    = "unbound.service.consul#5335"
        PIHOLE_DNS_2                    = "192.168.1.225"
        TZ                              = "America/Los_Angeles"
        WEB_PORT                        = "80"
        FTLCONF_webserver_api_password  = "test"
        VIRTUAL_HOST                    = "0.0.0.0"
      }

      # -------------------------------------------------------------------------
      # Custom dnsmasq configuration template (restarts on change)
      # -------------------------------------------------------------------------
      template {
        destination = "/etc/dnsmasq.d/02-custom.conf"
        change_mode = "restart"
        data = <<-EOT
bind-interfaces
listen-address=0.0.0.0
local-service
EOT
      }

      # -------------------------------------------------------------------------
      # Resource allocation for the Pi-hole container
      # -------------------------------------------------------------------------
      resources {
        cpu    = 150
        memory = 128
      }

      # -------------------------------------------------------------------------
      # Restart policy for the Pi-hole task
      # -------------------------------------------------------------------------
      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
