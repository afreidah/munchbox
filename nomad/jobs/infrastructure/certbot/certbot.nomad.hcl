# -------------------------------------------------------------------------------
# Certbot — Centralized Let's Encrypt Certificate Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Periodic job that acquires/renews Let's Encrypt certificates using Cloudflare
# DNS challenge and stores them in Vault. This allows multiple Traefik instances
# to share the same certificates without ACME storage race conditions.
# -------------------------------------------------------------------------------

job "certbot" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "batch"
  node_pool   = "all"
  priority    = 80

  # ---------------------------------------------------------------------------
  # Periodic Configuration — Run twice daily for renewal checks
  # ---------------------------------------------------------------------------

  periodic {
    crons            = ["0 0,12 * * *"]
    prohibit_overlap = true
    time_zone        = "America/Los_Angeles"
  }

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Task Group: certbot
  # ---------------------------------------------------------------------------

  group "certbot" {
    count = 1

    # --- Constraint: Run on stabler (has gdrive mount for cert persistence) ---
    constraint {
      attribute = "${node.unique.name}"
      value     = "stabler.munchbox.cc"
    }

    # --- Restart Policy ---
    restart {
      attempts = 2
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    # -------------------------------------------------------------------------
    # Task: certbot
    # -------------------------------------------------------------------------

    task "certbot" {
      driver = "docker"

      # --- Vault Integration (for Cloudflare token) ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image        = "certbot/dns-cloudflare:v3.3.0"
        entrypoint   = ["/bin/sh"]
        args         = ["/local/renew-certs.sh"]
        volumes      = [
          # Persistent certbot data and traefik cert output on shared NFS
          "/mnt/gdrive/munchbox-data/certbot:/etc/letsencrypt"
        ]
      }

      # --- Cloudflare API credentials ---
      template {
        destination = "secrets/cloudflare.ini"
        perms       = "0600"
        data        = <<-EOF
{{ with secret "secret/data/traefik" }}
dns_cloudflare_api_token = {{ .Data.data.cloudflare_api_token }}
{{ end }}
        EOF
      }

      # --- Certificate renewal script ---
      template {
        destination = "local/renew-certs.sh"
        perms       = "0755"
        data        = <<-EOF
#!/bin/sh
set -e

echo "=== Certbot Certificate Renewal ==="
echo "Time: $(date)"

# Request/renew certificate for munchbox.cc wildcard
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /secrets/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  --email alex@alexfreidah.com \
  --agree-tos \
  --non-interactive \
  --keep-until-expiring \
  --expand \
  -d "munchbox.cc" \
  -d "*.munchbox.cc"

# Check if certs exist
CERT_PATH="/etc/letsencrypt/live/munchbox.cc"
if [ ! -f "$CERT_PATH/fullchain.pem" ] || [ ! -f "$CERT_PATH/privkey.pem" ]; then
  echo "ERROR: Certificate files not found!"
  exit 1
fi

# Copy certs to shared NFS location for Traefik instances
# Maps to /mnt/gdrive/munchbox-data/certbot/traefik on the host
DEST="/etc/letsencrypt/traefik"
mkdir -p "$DEST"
cp "$CERT_PATH/fullchain.pem" "$DEST/munchbox.crt"
cp "$CERT_PATH/privkey.pem" "$DEST/munchbox.key"
chmod 644 "$DEST/munchbox.crt"
chmod 600 "$DEST/munchbox.key"

echo "SUCCESS: Certificates deployed to $DEST"
ls -la "$DEST"
echo "=== Certbot Complete ==="
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
