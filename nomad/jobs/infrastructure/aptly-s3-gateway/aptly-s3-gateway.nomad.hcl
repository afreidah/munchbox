# -------------------------------------------------------------------------------
# aptly-s3-gateway — SigV4-signing reverse proxy for the apt repo
#
# Project: Munchbox / Author: Alex Freidah
#
# Apt clients don't speak SigV4. This job runs nginx-s3-gateway, which
# transparently signs incoming HTTP requests and forwards them to s3-orchestrator
# so the apt repo's S3-backed publish tree (dists/, pool/) is reachable to apt.
#
# Lives in its own Nomad job (separate from aptly itself) so nginx-s3-gateway
# and aptly's bundled nginx don't fight over port 80 inside a shared alloc
# network namespace.
# -------------------------------------------------------------------------------

job "aptly-s3-gateway" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  group "gateway" {
    count = 1

    # Pin to amd64 — nginx-s3-gateway image only ships amd64 with njs-oss.
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    network {
      mode = "bridge"
      port "http" {
        static = 8092
        to     = 80
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service registration with Traefik routes for /dists/ and /pool/ ---
    # Higher priority than the catch-all aptly route so apt clients hit the
    # gateway directly rather than aptly's bundled nginx for these paths.
    service {
      name     = "aptly-s3-gateway"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS routers
        "traefik.http.routers.aptly-s3-dists.rule=Host(`apt.munchbox.cc`) && PathPrefix(`/dists/`)",
        "traefik.http.routers.aptly-s3-dists.entrypoints=websecure",
        "traefik.http.routers.aptly-s3-dists.tls=true",
        "traefik.http.routers.aptly-s3-dists.priority=100",
        "traefik.http.routers.aptly-s3-pool.rule=Host(`apt.munchbox.cc`) && PathPrefix(`/pool/`)",
        "traefik.http.routers.aptly-s3-pool.entrypoints=websecure",
        "traefik.http.routers.aptly-s3-pool.tls=true",
        "traefik.http.routers.aptly-s3-pool.priority=100",
        # HTTP routers (Cloudflare tunnel)
        "traefik.http.routers.aptly-s3-dists-http.rule=Host(`apt.munchbox.cc`) && PathPrefix(`/dists/`)",
        "traefik.http.routers.aptly-s3-dists-http.entrypoints=web",
        "traefik.http.routers.aptly-s3-dists-http.middlewares=cf-tunnel-https@file",
        "traefik.http.routers.aptly-s3-dists-http.priority=100",
        "traefik.http.routers.aptly-s3-pool-http.rule=Host(`apt.munchbox.cc`) && PathPrefix(`/pool/`)",
        "traefik.http.routers.aptly-s3-pool-http.entrypoints=web",
        "traefik.http.routers.aptly-s3-pool-http.middlewares=cf-tunnel-https@file",
        "traefik.http.routers.aptly-s3-pool-http.priority=100",
      ]

      check {
        name     = "tcp-health"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "gateway" {
      driver = "docker"

      vault {
        role        = "aptly-s3-gateway"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        # TODO: pin to a specific date tag after first successful deploy.
        image              = "nginxinc/nginx-s3-gateway:latest-njs-oss-20260413"
        image_pull_timeout = "5m"
        ports              = ["http"]
        volumes = [
          "local/apt-metadata-nocache.conf:/etc/nginx/conf.d/zz-apt-metadata-nocache.conf:ro",
        ]
      }

      # --- Never cache apt repo metadata (dists/) ---
      # InRelease pins exact hashes of Packages/Packages.bz2. The server-level
      # proxy_cache (1h) caches each object independently, so right after a
      # publish apt can get a fresh InRelease against a still-cached old Packages
      # -> "File has unexpected size" and the new index is rejected. dists/ must
      # always be served straight from S3; pool/*.deb are immutable so they stay
      # cached. http-context directives are inherited into the @s3 cache location.
      template {
        destination = "local/apt-metadata-nocache.conf"
        perms       = "0644"
        data        = <<-EOF
map $request_uri $apt_no_cache {
    default      0;
    "~^/dists/"  1;
}
proxy_no_cache     $apt_no_cache;
proxy_cache_bypass $apt_no_cache;
        EOF
      }

      # --- AWS credentials from Vault (env-injected) ---
      template {
        destination = "secrets/aws.env"
        perms       = "0600"
        env         = true
        data        = <<-EOF
{{ with secret "secret/data/aptly" -}}
AWS_ACCESS_KEY_ID={{ .Data.data.s3_access_key }}
AWS_SECRET_ACCESS_KEY={{ .Data.data.s3_secret_key }}
{{- end }}
        EOF
      }

      # --- Gateway configuration ---
      env {
        S3_BUCKET_NAME                      = "aptly"
        S3_SERVER                           = "s3-orchestrator.service.consul"
        S3_SERVER_PORT                      = "9000"
        S3_SERVER_PROTO                     = "http"
        S3_REGION                           = "us-east-1"
        S3_STYLE                            = "path"
        AWS_SIGS_VERSION                    = "4"
        ALLOW_DIRECTORY_LIST                = "true"
        PROVIDE_INDEX_PAGE                  = "false"
        APPEND_SLASH_FOR_POSSIBLE_DIRECTORY = "true"
        DIRECTORY_LISTING_PATH_PREFIX       = ""
        # Required cache directives (no defaults in image)
        PROXY_CACHE_VALID_OK        = "1h"
        PROXY_CACHE_VALID_NOTFOUND  = "1m"
        PROXY_CACHE_VALID_FORBIDDEN = "30s"
        # Required by 00-check-for-required-env.sh
        HEADER_PREFIXES_TO_STRIP = ""
        CORS_ENABLED             = "false"
        DEBUG                    = "false"
      }

      resources {
        cpu    = 100
        memory = 64
      }

      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
