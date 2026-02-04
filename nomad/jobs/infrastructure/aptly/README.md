# Aptly

Self-hosted Debian package repository for distributing custom homelab
packages. Bundles nginx (for serving the repo) and the aptly API in a
single image. Nodes can add `apt.munchbox.cc` as an APT source to
install cluster-specific packages.

## Architecture

The job uses four tasks with lifecycle hooks to handle first-run setup.
Two prestart tasks run before the main aptly server: one imports a GPG
signing key from Vault, and another downloads the web UI release. A
poststart task waits for the API to become ready, then creates the
initial repository and publishes a snapshot if they do not already exist.

## Components

| Task        | Role                          | Lifecycle |
|-------------|-------------------------------|-----------|
| setup-gpg   | Import GPG signing key        | prestart  |
| setup-webui | Download aptly-web-ui release | prestart  |
| aptly       | Main server (nginx + API)     | main      |
| setup-repo  | Create repo and publish       | poststart |

## Notable Configuration

- Constrained to AMD64 nodes (image has no ARM build)
- GPG import is idempotent with a marker file to skip on subsequent runs
- Web UI version tracked with a marker for clean upgrades
- htpasswd authentication for the API from Vault
- Data persists on gdrive NFS mount at `/mnt/gdrive/aptly`

## Dependencies

- **Vault** -- GPG private key and API htpasswd credentials
