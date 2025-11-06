# -------------------------------------------------------------------------------
#  Nginx Resume — Static Site Serving with Public and Internal Access
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Serves static resume HTML content from host volume on mccoy node. Exposes
#  via both internal Traefik router (resume.munchbox, TLS, LAN-only) and public
#  router (alexfreidah.com, http via cloudflared). Includes per-IP rate limiting
#  and connection caps to protect against floods.
# -------------------------------------------------------------------------------

job "nginx-resume-hostfile" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "service"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "1.0.0"
    owner       = "alex.freidah"
    category    = "infrastructure"
    tier        = "tier-2"
    environment = "production"
    description = "Static resume site with Nginx and rate limiting"
  }

  # --- Job update strategy ---
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Nginx Resume Group
  # ---------------------------------------------------------------------------

  group "web" {
    count = 1

    # --- Placement constraints ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # --- Static site content volume ---
    volume "site" {
      type      = "host"
      source    = "nginx-resume"
      read_only = true
    }

    # --- Network configuration ---
    network {
      port "http" {
        static = 8080
        to     = 80
      }
    }

    # --- Task restart behavior ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # -----------------------------------------------------------------------
    #  Nginx Task
    # -----------------------------------------------------------------------

    task "nginx" {
      driver = "docker"

      # --- Docker image configuration ---
      config {
        image = "nginx:stable"
        ports = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]
      }

      # --- Static site content volume mount ---
      volume_mount {
        volume      = "site"
        destination = "/usr/share/nginx/html"
        read_only   = true
      }

      # --- Nginx server configuration template ---
      # Serves resume.html at root with per-IP rate limiting and connection caps
      template {
        destination = "local/default.conf"
        data        = <<-EOT
# -----------------------------------------------------------------------
#  Nginx Server Configuration — Static Resume Site
# -----------------------------------------------------------------------

# --- Rate limiting zone: 10 req/s per IP ---
limit_req_zone  $binary_remote_addr  zone=resume_req_zone:10m  rate=10r/s;

# --- Connection limiting zone: 20 concurrent per IP ---
limit_conn_zone $binary_remote_addr  zone=resume_conn_zone:10m;

server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;

  # --- Serve resume.html at root ---
  index resume.html index.html;

  # --- Per-IP concurrent connection limit ---
  limit_conn resume_conn_zone 20;

  location / {
    # --- Fallback to resume.html for SPA routing ---
    try_files $uri $uri/ /resume.html;

    # --- Per-IP rate limit: 10 req/s with 20-request burst ---
    limit_req zone=resume_req_zone burst=20 nodelay;
  }
}
EOT
      }

      # --- Service registration ---
      service {
        name = "nginx-resume"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.resume-public.rule=Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)",
          "traefik.http.routers.resume-public.entrypoints=web",
          "traefik.http.routers.resume-public.service=nginx-resume",
          "traefik.http.services.nginx-resume.loadbalancer.server.port=8080",
          "traefik.http.routers.resume-internal.rule=Host(`resume.munchbox`)",
          "traefik.http.routers.resume-internal.entrypoints=websecure",
          "traefik.http.routers.resume-internal.tls=true",
          "traefik.http.routers.resume-internal.middlewares=dashboard-allowlan@file",
          "web",
          "resume",
          "nginx"
        ]

        # --- Health check ---
        check {
          name     = "nginx-resume"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      # --- Resource allocation ---
      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
