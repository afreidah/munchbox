###############################################################################
# Pi-hole — Nomad Job (with persistent volumes under /opt/nomad/data)
#
# - Runs Pi-hole using official Docker image
# - Persists both /etc/pihole and /etc/dnsmasq.d on the host at /opt/nomad/data/…
# - Registers with Consul for service discovery
# - Routes through Traefik at https://pihole.lan
# - Uses host networking (required for DNS/DHCP)
# - Binds HTTP on port 80 to avoid conflict with Traefik on port 80
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
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
# ──────────────────────────────────────────────────────────────────────────────

job "pihole" {
  datacenters = ["pi-dc"]
  type        = "service"

  meta {
    run_uuid = "${uuidv4()}"
  }

  group "pihole" {
    count = 1

    constraint {
      attribute = "${node.class}"
      operator  = "="
      value     = "pi5"
    }

    # ────────────────────────────────────────────────────────────────
    # Attach the two host_volumes declared in client.hcl
    # ────────────────────────────────────────────────────────────────
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

    # ────────────────────────────────────────────────────────────────
    # Host networking for full control over ports
    # ────────────────────────────────────────────────────────────────
    network {
      mode = "host"
      port "dns"   { static = 53  }
      port "dhcp"  { static = 67  }
      port "https" { static = 443 }
      port "http"  { static = 80 }

    }

    # ────────────────────────────────────────────────────────────────
    # Pi-hole Task
    # ────────────────────────────────────────────────────────────────
    task "pihole" {
      driver = "docker"

      # ────────────────────────────────────────────────────────────────
      # Register Pi-hole in Consul (must live here, inside the task)
      # ────────────────────────────────────────────────────────────────
      service {
        name     = "pihole"
        port     = "http"         # matches network.port "http"
        provider = "consul"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.pihole.rule=Host(`pihole.lan`)",
          "traefik.http.routers.pihole.entrypoints=traefik",
          "traefik.http.services.pihole.loadbalancer.server.port=80",
        ]

        check {
          name     = "pihole-tcp"
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }

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

      config {
        image              = "pihole/pihole:latest"
        network_mode       = "host"
        privileged         = true
        image_pull_timeout = "10m"
        ports              = ["dns", "dhcp", "http", "https"]
      }

      env = {
        PIHOLE_DNSMASQ_LISTENING        = "all"
        PIHOLE_DNS_1                    = "unbound.service.consul#5335"
        PIHOLE_DNS_2                    = "192.168.1.225"
        TZ                              = "America/Los_Angeles"
        WEB_PORT                        = "80"      # changed from "80"
        FTLCONF_webserver_api_password  = "test"
        VIRTUAL_HOST                    = "0.0.0.0"
      }

      template {
        destination = "/etc/dnsmasq.d/02-custom.conf"
        change_mode = "restart"
        data = <<-EOT
bind-interfaces
listen-address=0.0.0.0
local-service
EOT
      }

      resources {
        cpu    = 150
        memory = 128
      }

      restart {
        attempts = 5
        interval = "10m"
        delay    = "30s"
        mode     = "fail"
      }
    }
  }
}
