# -------------------------------------------------------------------------------
# Forgejo — Self-Hosted Git Repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Forgejo provides a lightweight, self-hosted Git service with push mirroring
# to GitHub. Integrates with Woodpecker CI via webhooks and Authentik for SSO.
# Git operations (push/pull) use Forgejo's native auth (tokens/SSH keys).
# -------------------------------------------------------------------------------

# --- Shared Variables (from shared.vars.hcl) ---
variable "pihole_1" { type = string }
variable "pihole_2" { type = string }

job "forgejo" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  # Note: No canary - static SSH port 2222 prevents running two instances
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: forgejo
  # ---------------------------------------------------------------------------

  group "forgejo" {
    count = 1

    # --- Constraint: Require gdrive NFS mount ---
    constraint {
      attribute = "${node.unique.name}"
      value     = "stabler.munchbox.cc"
    }

    # --- Network Configuration ---
    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
      port "ssh" {
        static = 2222
        to     = 22
      }
      # Bridge mode containers need explicit DNS config for Consul resolution
      # Uses node's dnsmasq (via CoreDNS) with Pi-hole fallbacks
      dns {
        servers  = ["${attr.unique.network.ip-address}", var.pihole_1, var.pihole_2]
        searches = ["service.consul"]
        options  = ["ndots:1", "timeout:2", "attempts:2"]
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "30s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "10m"
      unlimited      = false
    }

    # --- Service Registration (HTTP) ---
    service {
      name     = "forgejo"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router for API (no oauth2-proxy, higher priority)
        "traefik.http.routers.forgejo-api.rule=Host(`git.munchbox.cc`) && PathPrefix(`/api/`)",
        "traefik.http.routers.forgejo-api.entrypoints=websecure",
        "traefik.http.routers.forgejo-api.tls=true",
        "traefik.http.routers.forgejo-api.middlewares=forgejo-api-ratelimit@file",
        "traefik.http.routers.forgejo-api.priority=10",
        # HTTPS router for git operations (no oauth2-proxy, higher priority)
        "traefik.http.routers.forgejo-git.rule=Host(`git.munchbox.cc`) && PathRegexp(`/.+\\.git/.*`)",
        "traefik.http.routers.forgejo-git.entrypoints=websecure",
        "traefik.http.routers.forgejo-git.tls=true",
        "traefik.http.routers.forgejo-git.priority=10",
        # HTTPS router for web UI (with oauth2-proxy)
        "traefik.http.routers.forgejo.rule=Host(`git.munchbox.cc`)",
        "traefik.http.routers.forgejo.entrypoints=websecure",
        "traefik.http.routers.forgejo.tls=true",
        "traefik.http.routers.forgejo.tls.certresolver=letsencrypt",
        "traefik.http.routers.forgejo.middlewares=oauth2-proxy@file,umami-tracking@file",
        # HTTP router for API (no oauth2-proxy, higher priority)
        "traefik.http.routers.forgejo-api-http.rule=Host(`git.munchbox.cc`) && PathPrefix(`/api/`)",
        "traefik.http.routers.forgejo-api-http.entrypoints=web",
        "traefik.http.routers.forgejo-api-http.middlewares=cf-tunnel-https@file,forgejo-api-ratelimit@file",
        "traefik.http.routers.forgejo-api-http.priority=10",
        # HTTP router for git operations (no oauth2-proxy, higher priority)
        "traefik.http.routers.forgejo-git-http.rule=Host(`git.munchbox.cc`) && PathRegexp(`/.+\\.git/.*`)",
        "traefik.http.routers.forgejo-git-http.entrypoints=web",
        "traefik.http.routers.forgejo-git-http.middlewares=cf-tunnel-https@file",
        "traefik.http.routers.forgejo-git-http.priority=10",
        # HTTP router for web UI (with oauth2-proxy)
        "traefik.http.routers.forgejo-http.rule=Host(`git.munchbox.cc`)",
        "traefik.http.routers.forgejo-http.entrypoints=web",
        "traefik.http.routers.forgejo-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file,umami-tracking@file",
        "git",
        "forgejo",
        "infrastructure"
      ]

      check {
        name     = "forgejo-health"
        type     = "http"
        path     = "/api/healthz"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # --- Service Registration (SSH) ---
    service {
      name     = "forgejo-ssh"
      port     = "ssh"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "git-ssh"
      ]

      check {
        name     = "forgejo-ssh"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: init-config (copy config to writable location)
    # -------------------------------------------------------------------------

    task "init-config" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image   = "busybox:1.37.0"
        command = "sh"
        args    = ["-c", "mkdir -p /data/gitea/conf && cp /local/app.ini /data/gitea/conf/app.ini && chown -R 1000:1000 /data/gitea"]
        volumes = [
          "/mnt/gdrive/forgejo:/data",
          "local/app.ini:/local/app.ini:ro"
        ]
      }

      # --- Forgejo Configuration Template ---
      template {
        destination = "local/app.ini"
        data        = <<EOH
; Forgejo Configuration
; Generated by Nomad
{{ with secret "secret/data/forgejo" }}
{{ with .Data.data }}
[server]
APP_NAME = Munchbox Git
DOMAIN = git.munchbox.cc
ROOT_URL = https://git.munchbox.cc/
HTTP_PORT = 3000
SSH_DOMAIN = git.munchbox.cc
SSH_PORT = 2222
SSH_LISTEN_PORT = 22
LFS_START_SERVER = true
LFS_JWT_SECRET = {{ .lfs_jwt_secret }}
OFFLINE_MODE = false

[database]
DB_TYPE = postgres
HOST = postgres-primary.service.consul:5432
NAME = forgejo
USER = {{ .db_username }}
PASSWD = {{ .db_password }}
SSL_MODE = disable
LOG_SQL = false

[security]
INSTALL_LOCK = true
SECRET_KEY = {{ .secret_key }}
INTERNAL_TOKEN = {{ .internal_token }}

[oauth2]
JWT_SECRET = {{ .jwt_secret }}
{{ end }}{{ end }}
{{ with secret "secret/data/redis-shared" }}
{{ with .Data.data }}
[cache]
ADAPTER = redis
HOST = redis://default:{{ .password }}@redis-primary.service.consul:6379/2
ITEM_TTL = 16h

[session]
PROVIDER = redis
PROVIDER_CONFIG = redis://default:{{ .password }}@redis-primary.service.consul:6379/2
COOKIE_SECURE = true
SAME_SITE = lax

[queue]
TYPE = redis
CONN_STR = redis://default:{{ .password }}@redis-primary.service.consul:6379/2
{{ end }}{{ end }}

[indexer]
ISSUE_INDEXER_TYPE = bleve
REPO_INDEXER_ENABLED = true

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = false
ENABLE_NOTIFY_MAIL = false

[mailer]
ENABLED = false

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
USERNAME = email
UPDATE_AVATAR = true
ACCOUNT_LINKING = auto

[log]
MODE = console
LEVEL = Info

[repository]
ROOT = /data/git/repositories
DEFAULT_BRANCH = main

[repository.upload]
TEMP_PATH = /data/gitea/uploads

[lfs]
PATH = /data/git/lfs

[picture]
AVATAR_UPLOAD_PATH = /data/gitea/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars

[attachment]
PATH = /data/gitea/attachments

[webhook]
; Restrict webhooks to internal services and munchbox.cc domain (prevents SSRF)
ALLOWED_HOST_LIST = loopback,*.service.consul,*.munchbox.cc

[migrations]
ALLOWED_DOMAINS = github.com,api.github.com,gitlab.com
ALLOW_LOCALNETWORKS = true

[mirror]
ENABLED = true
DEFAULT_INTERVAL = 8h

[opentelemetry]
ENABLED = true
EXPORTER = otlp
ENDPOINT = tempo.service.consul:4317
SERVICE_NAME = forgejo

[metrics]
ENABLED = true
ENABLED_ISSUE_BY_LABEL = true
ENABLED_ISSUE_BY_REPOSITORY = true
EOH
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: forgejo
    # -------------------------------------------------------------------------

    task "forgejo" {
      driver = "docker"

      # --- Container Configuration ---
      config {
        image              = "codeberg.org/forgejo/forgejo:10"
        image_pull_timeout = "10m"
        ports              = ["http", "ssh"]
        volumes            = [
          "/mnt/gdrive/forgejo:/data"
        ]
      }

      # --- Environment Variables ---
      env {
        USER_UID = "1000"
        USER_GID = "1000"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 512
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
