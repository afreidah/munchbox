# ------------------------------------------------------------------------------
# Nginx Static Site — via PIA WireGuard (Gluetun sidecar, CUSTOM provider)
# ------------------------------------------------------------------------------
# Purpose:
#   - Only THIS job's egress flows through PIA (privacy/geo policy).
#   - Inbound comes from Traefik locally; Cloudflare reaches Traefik via Tunnel.
#
# Host content:
#   /opt/nomad/data/nginx-resume/resume.html
#
# REQUIRED on any Nomad client that can run this job:
#   client {
#     host_volume "nginx-resume" {
#       path      = "/opt/nomad/data/nginx-resume"
#       read_only = true
#     }
#   }
# ------------------------------------------------------------------------------

job "nginx-resume-hostfile" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "web" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # ----------------------- Networking (shared namespace) ---------------------
    # bridge mode => tasks share a netns; the VPN sidecar governs egress
    network {
      mode = "bridge"

      # Traefik will reach this on the alloc; cloudflared reaches Traefik
      port "http" {
        to     = 80
        static = 8080     # matches your current file-provider wiring
      }
    }

    # ----------------------- Content volume -----------------------------------
    volume "site" {
      type      = "host"
      source    = "nginx-resume"
      read_only = true
    }

		# ------------------------------------------------------------------
		# Gluetun (WireGuard custom) — consumes wg0.conf from Consul KV
		# ------------------------------------------------------------------
		task "vpn" {
			driver = "docker"

			config {
				image   = "qmcgaw/gluetun:latest"
				cap_add = ["NET_ADMIN"]
				devices = [
					{ host_path="/dev/net/tun", container_path="/dev/net/tun", cgroup_permissions="rwm" }
				]
				volumes = [
					"local/gluetun:/gluetun",
					"local/wg0.conf:/gluetun/wireguard/wg0.conf:ro"
				]
			}

			env {
				VPN_TYPE             = "wireguard"
				VPN_SERVICE_PROVIDER = "custom"
				FIREWALL             = "on"
				TZ                   = "America/Los_Angeles"
			}

			# Renders your KV value to local/wg0.conf at alloc start
			template {
				destination = "local/wg0.conf"
				change_mode = "restart"
				data = <<-EOT
					{{ key "secrets/pia/wg0.conf" }}
				EOT
			}

			resources { 
				cpu = 100
				memory = 128
			}
		}

    # ----------------------- App: Nginx (served to Traefik) -------------------
    task "nginx" {
      driver = "docker"

      config {
        image  = "nginx:stable"
        ports  = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]
      }

      volume_mount {
        volume      = "site"
        destination = "/usr/share/nginx/html"
        read_only   = true
      }

      template {
        destination = "local/default.conf"
        data = <<-EOT
          server {
            listen 80;
            server_name _;
            root /usr/share/nginx/html;
            index resume.html index.html;

            location / {
              try_files /resume.html $uri $uri/ =404;
            }
          }
        EOT
      }

      resources { 
				cpu = 200
				memory = 256
			}

      # Consul registration so Traefik can route by Host()
      service {
        name = "nginx-resume"
        port = "http"
        check {
          type     = "http"
          path     = "/resume.html"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.resume.rule=Host(`resume.alexfreidah.com`)",
          "traefik.http.routers.resume.entrypoints=web",
          "traefik.http.services.resume.loadbalancer.server.port=80"
        ]
      }
    }
  }
}
