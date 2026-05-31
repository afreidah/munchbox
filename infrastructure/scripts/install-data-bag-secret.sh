#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# install-data-bag-secret.sh
#
# One-shot workstation-side bootstrap: pulls the shared cinc data-bag
# secret out of Vault and scp's it to a node's
# /etc/cinc/encrypted_data_bag_secret. Required once per node before
# cinc-client can decrypt any encrypted data bag item (e.g. the
# vault_agent AppRole creds).
#
# Idempotent -- safe to re-run; the file is overwritten in-place. Use the
# same flow whenever you need to rotate the secret (rotate in Vault,
# re-encrypt every item, then run this against each node).
#
# Usage:
#   source munchbox-env.sh
#   infrastructure/scripts/install-data-bag-secret.sh <ssh-target>
#
# Example:
#   ./install-data-bag-secret.sh ubuntu@oraclearm2
#   ./install-data-bag-secret.sh root@stabler
# -------------------------------------------------------------------------------
set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "usage: $0 <ssh-target>   e.g. ubuntu@oraclearm2 or root@stabler" >&2
  exit 1
fi

for var in VAULT_ADDR VAULT_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is empty -- did you source munchbox-env.sh?" >&2
    exit 1
  fi
done

command -v vault >/dev/null || { echo "error: vault CLI not on PATH" >&2; exit 1; }
command -v ssh >/dev/null   || { echo "error: ssh not on PATH" >&2; exit 1; }
command -v scp >/dev/null   || { echo "error: scp not on PATH" >&2; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

SECRET_FILE="$WORKDIR/secret"
install -m 0600 /dev/null "$SECRET_FILE"
vault kv get -field=value secret/cinc/encrypted_data_bag_secret > "$SECRET_FILE"

# --- Detect oracle nodes (ubuntu user) vs bare metal (root) and gate sudo accordingly ---
SSH_USER="${TARGET%@*}"
SUDO=""
if [[ "$SSH_USER" != "root" ]]; then
  SUDO="sudo"
fi

# --- Stage under /tmp first, then sudo-install into /etc/cinc so the file lands with the right perms in one shot ---
REMOTE_TMP="/tmp/encrypted_data_bag_secret.$$"
scp -q "$SECRET_FILE" "$TARGET:$REMOTE_TMP"
ssh "$TARGET" "$SUDO install -d -m 0755 /etc/cinc && $SUDO install -m 0640 -o root -g root '$REMOTE_TMP' /etc/cinc/encrypted_data_bag_secret && rm -f '$REMOTE_TMP'"

echo "installed /etc/cinc/encrypted_data_bag_secret on $TARGET"
