# ------------------------------------------------------------------------------
# Nginx Static Site — Serve prebuilt HTML from Nomad host_volume on mccoy
# ------------------------------------------------------------------------------

job "nginx-resume-hostfile" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "web" {
    count = 1

    # Force this to run on mccoy
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    volume "site" {
      type      = "host"
      source    = "nginx-resume"
      read_only = true
    }

    network {
      port "http" {
        to     = 80
        static = 8080
      }
    }

    task "nginx" {
      driver = "docker"
      config {
        image = "nginx:stable"
        ports = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]

        # Logging configuration
        logging {
          type = "journald"
          config {
            tag = "nginx-resume"
          }
        }
      }

      volume_mount {
        volume      = "site"
        destination = "/usr/share/nginx/html"
        read_only   = true
      }

      # ------------------------------------------------------------------------
      # Template — /etc/nginx/conf.d/default.conf (rendered into local/default.conf)
      # - Serves resume.html at "/"
      # - Adds per-IP rate/conn limits to resist floods
      # ------------------------------------------------------------------------
      template {
        destination = "local/default.conf"
        data        = <<-EOT
                                        # -----------------------------------------------------------------------------
                                        # NGINX server for resume.alexfreidah.com — static, read-only content
                                        # -----------------------------------------------------------------------------

                                        # --- Global zones (http context) ---
                                        # Per-IP request rate: 10 req/s (burst allowed below)
                                        limit_req_zone  $binary_remote_addr  zone=resume_req_zone:10m  rate=10r/s;

                                        # Per-IP concurrent connections cap
                                        limit_conn_zone $binary_remote_addr  zone=resume_conn_zone:10m;

                                        server {
                                                listen 80;
                                                server_name _;
                                                root /usr/share/nginx/html;

                                                # Serve resume.html at "/"
                                                index resume.html index.html;

                                                # Cap total concurrent connections per IP
                                                limit_conn resume_conn_zone 20;

                                                location / {
                                                        # Try request path first, then fallback to resume.html
                                                        try_files $uri $uri/ /resume.html;

                                                        # Apply per-IP rate limit: allow short bursts without delay
                                                        limit_req zone=resume_req_zone burst=20 nodelay;
                                                }
                                        }
                                EOT
      }

      resources {
        cpu    = 200
        memory = 128
      }

      service {
        name = "nginx-resume"
        port = "http"

        tags = [
          "traefik.enable=true",

          # Router configuration - INTERNAL access only
          "traefik.http.routers.resume-internal.rule=Host(`resume.munchbox`)",
          "traefik.http.routers.resume-internal.entrypoints=websecure",
          "traefik.http.routers.resume-internal.tls=true",

          # Restrict to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.resume-internal.middlewares=dashboard-allowlan@file",

          # Explicit backend port
          "traefik.http.services.nginx-resume.loadbalancer.server.port=8080",

          # Metadata tags
          "web",
          "resume",
          "nginx",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
