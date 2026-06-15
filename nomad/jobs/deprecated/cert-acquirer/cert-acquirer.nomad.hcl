# -------------------------------------------------------------------------------
# cert-acquirer
#
# Single source of truth for the *.munchbox.cc Let's Encrypt wildcard. One
# weekly job issues a fresh cert via Cloudflare DNS-01 and writes it to Vault
# at secret/traefik/wildcard; both Traefik ingress instances read that one
# cert. Replaces Traefik's per-instance ACME (which raced and split the cert).
#
# Stateless on purpose: a weekly fresh issue (1/week) stays well under the LE
# duplicate-cert limit (5/week) and the 90-day cert is never more than a week
# old, so no account/cert state needs persisting.
#
# Two stock images, ordered via lifecycle:
#   lego (prestart)    -- obtains the cert into /alloc/data
#   publish (main)     -- writes cert+key into Vault with its WI token
# -------------------------------------------------------------------------------

job "cert-acquirer" {
  datacenters = ["munchbox"]
  type        = "batch"

  periodic {
    crons            = ["0 4 * * 1"] # 04:00 every Monday
    prohibit_overlap = true
  }

  group "acquire" {
    # --- Don't retry: a publish failure must NOT re-run lego (every lego run
    #     is another LE issuance against the weekly duplicate-cert limit). ---
    restart {
      attempts = 0
      mode     = "fail"
    }
    reschedule {
      attempts  = 0
      unlimited = false
    }

    # --- Acquire + publish share the alloc dir; lego writes, publish reads. ---
    task "lego" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      # --- needed so the CF-token template can read from Vault ---
      vault {
        role = "cert-acquirer"
      }

      config {
        image      = "goacme/lego:v4.21.0"
        entrypoint = ["/bin/sh", "-c"]
        args = [<<-EOC
          set -eu
          /lego --accept-tos --email "$ACME_EMAIL" --dns cloudflare \
                --path /alloc/data/lego \
                -d '*.munchbox.cc' -d 'munchbox.cc' run
        EOC
        ]
      }

      env {
        ACME_EMAIL = "alex@alexfreidah.com"
      }

      # --- Cloudflare DNS-Write token (reused from the wandns token in Vault). ---
      template {
        destination = "secrets/cf.env"
        env         = true
        data        = <<-EOH
          {{ with secret "secret/data/cloudflare-wandns" -}}
          CLOUDFLARE_DNS_API_TOKEN={{ .Data.data.api_token }}
          {{- end }}
        EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "publish" {
      driver = "docker"

      # --- WI: job_id "cert-acquirer" matches the bound_claims on this role,
      #     granting nomad-workloads (read) + cert-acquirer (write wildcard). ---
      vault {
        role = "cert-acquirer"
      }

      config {
        image      = "hashicorp/vault:1.18"
        entrypoint = ["/bin/sh", "-c"]
        args = [<<-EOC
          set -eu
          export VAULT_TOKEN="$(cat "$NOMAD_SECRETS_DIR/vault_token")"
          D=/alloc/data/lego/certificates
          CRT="$(ls "$D"/*.crt 2>/dev/null | grep -v issuer | head -1)"
          KEY="$(ls "$D"/*.key 2>/dev/null | head -1)"
          test -n "$CRT" && test -n "$KEY"
          vault kv put secret/traefik/wildcard cert=@"$CRT" key=@"$KEY"
        EOC
        ]
        # --- mount the host CA bundle (carries the munchbox root+intermediate
        #     via cinc) so the vault CLI trusts Vault's TLS. ---
        volumes = ["/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"]
      }

      env {
        VAULT_ADDR = "https://vault.service.consul:8200"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
