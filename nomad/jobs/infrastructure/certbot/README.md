# Certbot

Periodic batch job that acquires and renews Let's Encrypt wildcard
certificates for `*.munchbox.cc` using the Cloudflare DNS challenge.
Runs twice daily to catch renewals before expiry.

## Architecture

Certbot authenticates against the Cloudflare API (token from Vault) to
prove domain ownership via DNS TXT records. After successful renewal, the
certificate files are copied to a shared NFS path where both Traefik
instances can read them. This avoids ACME storage race conditions that
would occur if each Traefik instance ran its own ACME resolver.

Certbot state (account data, renewal configs) persists on the gdrive
mount so renewal history survives across job runs.

## Notable Configuration

- Cloudflare propagation wait set to 60 seconds to handle slow DNS updates
- Pinned to stabler (has the gdrive NFS mount)
- Certificate output path: `/mnt/gdrive/munchbox-data/certbot/traefik/`

## Dependencies

- **Traefik** -- consumes the generated certificates
- **Vault** -- Cloudflare API token storage
