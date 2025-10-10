# ------------------------------------------------------------------------------
# Nginx Static Site — Serve prebuilt HTML from Nomad host_volume on mccoy
# ------------------------------------------------------------------------------
# What this job does
# - Runs a single nginx container on node "mccoy" to serve a static resume site.
# - Serves content from a Nomad host volume (source: "nginx-resume").
# - Publishes container port 80 to the node on static port 8080.
# - Registers a Nomad service with Traefik labels for BOTH:
#     * Internal access (Host: resume.munchbox on entrypoint websecure, LAN-only)
#     * Public access  (Host: alexfreidah.com OR www.alexfreidah.com on entrypoint web)
#
# Why this change?
# - Added a **public Traefik router** so traffic arriving with Host alexfreidah.com /
#   www.alexfreidah.com (from cloudflared → Traefik) matches a router and is forwarded
#   to this service on port 8080, removing the 404 previously seen at the edge.
# ------------------------------------------------------------------------------

job "nginx-resume-hostfile" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "web" {
    count = 1

    # --------------------------------------------------------------------------
    # Placement — force this job to run on node "mccoy"
    # --------------------------------------------------------------------------
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # --------------------------------------------------------------------------
    # Host volume — static site build artifacts live here on the node
    #   - Source "nginx-resume" should be defined in the client config.
    #   - Mounted read-only into /usr/share/nginx/html in the container.
    # --------------------------------------------------------------------------
    volume "site" {
      type      = "host"
      source    = "nginx-resume"
      read_only = true
    }

    # --------------------------------------------------------------------------
    # Networking — publish container :80 to node :8080 (static)
    #   - Traefik will forward to this published node port.
    # --------------------------------------------------------------------------
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

        # Rendered template below becomes the nginx server config
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]

        # Container logging (journald)
        logging {
          type = "journald"
          config {
            tag = "nginx-resume"
          }
        }
      }

      # ------------------------------------------------------------------------
      # Mount the static site content into the container (read-only)
      # ------------------------------------------------------------------------
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

      # ------------------------------------------------------------------------
      # Resources — conservative defaults for a small static site
      # ------------------------------------------------------------------------
      resources {
        cpu    = 200
        memory = 128
      }

      # ------------------------------------------------------------------------
      # Service Registration — Traefik integration
      #
      # INTERNAL ROUTER (unchanged):
      #   - Host: resume.munchbox
      #   - EntryPoint: websecure (TLS)
      #   - LAN-only via middleware "dashboard-allowlan@file"
      #
      # PUBLIC ROUTER (NEW):
      #   - Hosts: alexfreidah.com, www.alexfreidah.com
      #   - EntryPoint: web (:80) to match cloudflared → Traefik HTTP config
      #   - Forwards to service "nginx-resume" on server.port=8080
      # ------------------------------------------------------------------------
      service {
        name = "nginx-resume"
        port = "http"

        tags = [
          # Enable discovery by Traefik
          "traefik.enable=true",

          # ------------------------- PUBLIC ROUTER (NEW) -------------------------
          # Match the real domains that Cloudflare/Cloudflared sends via Traefik
          "traefik.http.routers.resume-public.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",

          # Traefik entrypoint receiving HTTP from cloudflared (port 80)
          "traefik.http.routers.resume-public.entrypoints=web",

          # Bind this router to the backend service defined below
          "traefik.http.routers.resume-public.service=nginx-resume",

          # Backend service definition — point to the Nomad-published node port
          "traefik.http.services.nginx-resume.loadbalancer.server.port=8080",
          # ----------------------------------------------------------------------

          # ------------------------- INTERNAL ROUTER (EXISTING) -----------------
          "traefik.http.routers.resume-internal.rule=Host(`resume.munchbox`)",
          "traefik.http.routers.resume-internal.entrypoints=websecure",
          "traefik.http.routers.resume-internal.tls=true",

          # Restrict internal router to LAN (middleware defined in Traefik file provider)
          "traefik.http.routers.resume-internal.middlewares=dashboard-allowlan@file",
          # ----------------------------------------------------------------------

          # Metadata tags
          "web",
          "resume",
          "nginx",
        ]

        # Basic HTTP health check on "/"
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
