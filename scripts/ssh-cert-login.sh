#!/bin/bash
# -------------------------------------------------------------------------------
# SSH Certificate Login
#
# Project: Munchbox / Author: Alex Freidah
#
# Signs your SSH public key with the Vault client CA for 8-hour interactive
# access. Run this when your certificate expires.
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN environment variables set
#   - ~/.ssh/id_ed25519.pub exists
#
# Usage:
#   ./scripts/ssh-cert-login.sh
#   ./scripts/ssh-cert-login.sh ~/.ssh/id_rsa.pub   # use a different key
# -------------------------------------------------------------------------------

set -e

PUB_KEY="${1:-$HOME/.ssh/id_ed25519.pub}"
CERT_FILE="${PUB_KEY%.pub}-cert.pub"

if [ ! -f "$PUB_KEY" ]; then
  echo "ERROR: Public key not found: $PUB_KEY"
  exit 1
fi

echo "Signing SSH key for Munchbox access..."
echo "  Key: $PUB_KEY"
echo ""

# --- Sign the key ---
vault write -field=signed_key ssh-client-signer/sign/client-user \
  public_key=@"$PUB_KEY" \
  valid_principals="root,ubuntu" > "$CERT_FILE"

echo "==> Certificate written to $CERT_FILE"

# --- Show certificate details ---
echo ""
ssh-keygen -Lf "$CERT_FILE" 2>/dev/null | grep -E '(Valid|Principals|Type)'

echo ""
echo "Done. Certificate valid for 8 hours."
