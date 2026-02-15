#!/bin/bash
# -------------------------------------------------------------------------------
# SSH CA Setup - Local Workstation
#
# Project: Munchbox / Author: Alex Freidah
#
# One-time setup to trust the Vault SSH host CA. After running this, SSH will
# verify host certificates instead of checking individual known_hosts entries.
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN environment variables set
#
# Usage:
#   ./scripts/ssh-ca-setup.sh
# -------------------------------------------------------------------------------

set -e

KNOWN_HOSTS="$HOME/.ssh/known_hosts"
MARKER="@cert-authority"

echo "Setting up SSH CA trust for Munchbox hosts..."
echo ""

# --- Fetch host CA public key from Vault ---
echo "==> Fetching host CA public key from Vault..."
HOST_CA=$(vault read -field=public_key ssh-host-signer/config/ca)

if [ -z "$HOST_CA" ]; then
  echo "ERROR: Failed to fetch host CA public key from Vault"
  exit 1
fi

echo "    CA key: ${HOST_CA:0:40}..."

# --- Add to known_hosts ---
ENTRY="$MARKER * $HOST_CA"

if grep -qF "$HOST_CA" "$KNOWN_HOSTS" 2>/dev/null; then
  echo "==> Host CA already in $KNOWN_HOSTS (skipping)"
else
  echo "==> Adding host CA to $KNOWN_HOSTS..."
  echo "$ENTRY" >> "$KNOWN_HOSTS"
  echo "    Added @cert-authority entry"
fi

echo ""
echo "Done. SSH will now trust Vault-signed host certificates."
echo ""
echo "Test with: ssh -v root@<any-node> (look for 'Server host certificate' in output)"
