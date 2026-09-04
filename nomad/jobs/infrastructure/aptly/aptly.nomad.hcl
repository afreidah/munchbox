# -------------------------------------------------------------------------------
# Aptly — Debian Package Repository
#
# Project: Munchbox / Author: Alex Freidah
#
# Self-hosted Debian repository for homelab packages. Uses urpylka/aptly image
# which bundles nginx + aptly API. Data persists on shared /mnt/gdrive storage.
# -------------------------------------------------------------------------------

job "aptly" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

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

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: aptly
  # ---------------------------------------------------------------------------

  group "aptly" {
    count = 1

    # --- Must be AMD64 (image doesn't support ARM) ---
    constraint {
      attribute = "${attr.cpu.arch}"
      value     = "amd64"
    }

    # --- Must have gdrive mount ---
    constraint {
      attribute = "${attr.unique.hostname}"
      operator  = "set_contains_any"
      value     = "goren,stabler,nomad-client-01,nomad-client-02,nomad-client-03"
    }

    network {
      mode = "bridge"
      port "http" {
        static = 8089
        to     = 80
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Web/API Service ---
    service {
      name     = "aptly"
      port     = "http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTP router (Cloudflare tunnel)
        "traefik.http.routers.aptly-http.rule=Host(`apt.munchbox.cc`)",
        "traefik.http.routers.aptly-http.entrypoints=web",
        "traefik.http.routers.aptly-http.middlewares=cf-tunnel-https@file",
        # HTTPS router (direct LAN access)
        "traefik.http.routers.aptly.rule=Host(`apt.munchbox.cc`)",
        "traefik.http.routers.aptly.entrypoints=websecure",
        "traefik.http.routers.aptly.tls=true",
      ]

      check {
        name     = "tcp-health"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }


    # -------------------------------------------------------------------------
    # Task: setup-gpg (prestart)
    # -------------------------------------------------------------------------

    task "setup-gpg" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      vault {
        role        = "aptly"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image   = "alpine:3.23.4"
        command = "/bin/sh"
        args    = ["/local/setup-gpg.sh"]

        volumes = [
          "/mnt/gdrive/aptly:/opt/aptly:rw",
        ]
      }

      template {
        destination = "secrets/gpg-private.asc"
        perms       = "0600"
        data        = <<-EOF
{{ with secret "secret/data/aptly" }}{{ .Data.data.gpg_private_key }}{{ end }}
        EOF
      }

      template {
        destination = "local/setup-gpg.sh"
        perms       = "0755"
        data        = <<-EOF
#!/bin/sh
set -e

GPG_DIR="/opt/aptly/gpg"
MARKER="$GPG_DIR/.imported"

# Check if already imported
if [ -f "$MARKER" ]; then
  echo "GPG key already imported"
  exit 0
fi

echo "Setting up GPG keyring..."
apk add --no-cache gnupg

# Create GPG home directory
mkdir -p "$GPG_DIR"
chmod 700 "$GPG_DIR"

# Import private key
GNUPGHOME="$GPG_DIR" gpg --batch --import /secrets/gpg-private.asc

# Trust the key ultimately (use full fingerprint from fpr line)
FPR=$(GNUPGHOME="$GPG_DIR" gpg --list-keys --with-colons | grep '^fpr' | head -1 | cut -d: -f10)
echo "$FPR:6:" | GNUPGHOME="$GPG_DIR" gpg --import-ownertrust

# Mark as imported
echo "imported" > "$MARKER"
echo "GPG key imported successfully (Fingerprint: $FPR)"
        EOF
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: setup-webui (prestart)
    # -------------------------------------------------------------------------

    task "setup-webui" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:3.23.4"
        command = "/bin/sh"
        args    = ["/local/setup-webui.sh"]

        volumes = [
          "/mnt/gdrive/aptly:/opt/aptly:rw",
        ]
      }

      # --- Web UI Setup Script ---
      template {
        destination = "local/setup-webui.sh"
        perms       = "0755"
        data        = <<-EOF
#!/bin/sh
set -e

WEBUI_VERSION="v0.2.2"
WEBUI_DIR="/opt/aptly/public/ui"
MARKER="$WEBUI_DIR/.version"

# Check if already installed
if [ -f "$MARKER" ] && [ "$(cat $MARKER)" = "$WEBUI_VERSION" ]; then
  echo "Web UI $WEBUI_VERSION already installed"
  exit 0
fi

echo "Installing aptly-web-ui $WEBUI_VERSION..."
apk add --no-cache curl tar

# Download and extract
mkdir -p "$WEBUI_DIR"
curl -fsSL "https://github.com/sdumetz/aptly-web-ui/releases/download/$WEBUI_VERSION/aptly-web-ui.tar.gz" -o /tmp/webui.tar.gz
tar -xzf /tmp/webui.tar.gz -C "$WEBUI_DIR" --strip-components=1

# Mark version
echo "$WEBUI_VERSION" > "$MARKER"
echo "Web UI installed at $WEBUI_DIR"
        EOF
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: setup-repo (poststart)
    # -------------------------------------------------------------------------

    task "setup-repo" {
      driver = "docker"
      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      # --- Vault Integration ---
      vault {
        role        = "aptly"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image   = "curlimages/curl:8.20.0"
        command = "/bin/sh"
        args    = ["/local/setup.sh"]
      }

      # --- Setup Script ---
      template {
        destination = "local/setup.sh"
        perms       = "0755"
        data        = <<-EOF
#!/bin/sh
set -e

API="http://localhost:8080/api"
AUTH="admin:{{ with secret "secret/data/aptly-admin" }}{{ .Data.data.password }}{{ end }}"

echo "Waiting for aptly API..."
for i in $(seq 1 30); do
  if curl -sf -u "$AUTH" "$API/version" >/dev/null 2>&1; then
    echo "API ready"
    break
  fi
  echo "Attempt $i/30..."
  sleep 2
done

# Create repo if it doesn't exist
if ! curl -sf -u "$AUTH" "$API/repos/munchbox" >/dev/null 2>&1; then
  echo "Creating munchbox repo..."
  curl -sf -u "$AUTH" -X POST -H 'Content-Type: application/json' \
    --data '{"Name":"munchbox","Comment":"Munchbox homelab packages","DefaultDistribution":"stable","DefaultComponent":"main"}' \
    "$API/repos"
  echo "Repo created"
else
  echo "Repo already exists"
fi

# Check if published
if ! curl -sf -u "$AUTH" "$API/publish/./stable" >/dev/null 2>&1; then
  # Create snapshot if none exists
  SNAP="munchbox-initial"
  if ! curl -sf -u "$AUTH" "$API/snapshots/$SNAP" >/dev/null 2>&1; then
    echo "Creating initial snapshot..."
    curl -sf -u "$AUTH" -X POST -H 'Content-Type: application/json' \
      --data "{\"Name\":\"$SNAP\"}" \
      "$API/repos/munchbox/snapshots"
  fi

  # Publish snapshot to S3
  echo "Publishing snapshot to S3..."
  curl -sf -u "$AUTH" -X POST -H 'Content-Type: application/json' \
    --data "{\"SourceKind\":\"snapshot\",\"Sources\":[{\"Name\":\"$SNAP\"}],\"Distribution\":\"stable\",\"Architectures\":[\"amd64\",\"arm64\"],\"Signing\":{\"Skip\":true},\"Storage\":\"s3:munchbox:\"}" \
    "$API/publish/:" || echo "Publish may already exist or GPG signing required"
fi

echo "Setup complete"
        EOF
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    # -------------------------------------------------------------------------
    # Task: aptly
    # -------------------------------------------------------------------------

    task "aptly" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role        = "aptly"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "urpylka/aptly:1.6.3"
        image_pull_timeout = "5m"
        ports              = ["http"]

        # Persistent storage on shared gdrive mount
        volumes = [
          "/mnt/gdrive/aptly:/opt/aptly:rw",
          "secrets/api.htpasswd:/opt/aptly/api.htpasswd:ro",
          "local/aptly.conf:/etc/aptly.conf:ro",
          "local/nginx-timeout.conf:/etc/nginx/conf.d/zz-timeout.conf:ro",
        ]
      }

      # --- nginx proxy timeout drop-in ---
      # The bundled nginx fronts the aptly API; its 60s default proxy_read_timeout
      # severs slow publish-switch calls (GPG sign + S3 upload) and aptly never
      # commits. conf.d is included inside http{}, so these http-context
      # directives raise the ceiling for every proxied request.
      template {
        destination = "local/nginx-timeout.conf"
        perms       = "0644"
        data        = <<-EOF
proxy_read_timeout 600s;
proxy_send_timeout 600s;
        EOF
      }

      # --- Aptly config with metrics enabled ---
      template {
        destination = "local/aptly.conf"
        perms       = "0644"
        data        = <<-EOF
{
  "rootDir": "/opt/aptly",
  "downloadConcurrency": 4,
  "downloadSpeedLimit": 0,
  "architectures": [],
  "dependencyFollowSuggests": false,
  "dependencyFollowRecommends": false,
  "dependencyFollowAllVariants": false,
  "dependencyFollowSource": false,
  "gpgDisableSign": false,
  "gpgDisableVerify": false,
  "gpgProvider": "gpg2",
  "downloadSourcePackages": false,
  "ppaDistributorID": "ubuntu",
  "ppaCodename": "",
  "enableMetricsEndpoint": true,
  "S3PublishEndpoints": {
    "munchbox": {
      "region": "us-east-1",
      "bucket": "aptly",
      "endpoint": "http://s3-orchestrator.service.consul:9000",
      "awsAccessKeyID": "{{ with secret "secret/data/s3-bucket/aptly" }}{{ .Data.data.access_key }}{{ end }}",
      "awsSecretAccessKey": "{{ with secret "secret/data/s3-bucket/aptly" }}{{ .Data.data.secret_key }}{{ end }}",
      "s3ForcePathStyle": true,
      "disableMultiDel": false
    }
  },
  "SwiftPublishEndpoints": {}
}
        EOF
      }

      # --- htpasswd from Vault ---
      template {
        destination = "secrets/api.htpasswd"
        perms       = "0644"
        data        = <<-EOF
{{ with secret "secret/data/aptly-admin" }}{{ .Data.data.htpasswd }}{{ end }}
        EOF
      }

      # --- Environment ---
      env {
        NGINX_CLIENT_MAX_BODY_SIZE = "500M"
        GNUPGHOME                  = "/opt/aptly/gpg"
      }

      # --- Resources ---
      resources {
        cpu    = 200
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }

  }
}
