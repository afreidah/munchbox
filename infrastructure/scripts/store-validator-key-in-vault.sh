#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# store-validator-key-in-vault.sh
#
# One-time setup: stash the chef/cinc organization's validator PEM in
# Vault so the bootstrap module can pull it via vault_kv_secret_v2 when
# cloud-init runs on a new node.
#
# Stores at secret/cinc/validator-key field `key` -- matches the
# defaults in the bootstrap terraform module (chef_validator_vault_*).
#
# Reads the PEM from stdin so this script doesn't care WHERE the key
# comes from. Two common sources:
#
#   1. The org-create file on cinc-server (if the org was bootstrapped
#      with `chef-server-ctl org-create ... -f <file>`):
#
#        ssh root@cinc-server.munchbox.cc 'cat /etc/cinc-bootstrap/munchbox-validator.pem' \
#          | infrastructure/scripts/store-validator-key-in-vault.sh
#
#   2. Regenerate via knife (DESTRUCTIVE -- invalidates any old copies
#      of the key, so any node bootstraps currently in flight will
#      fail. Validators are only used for the first cinc-client call;
#      after that the node has its own client.pem):
#
#        knife client reregister munchbox-validator \
#          | infrastructure/scripts/store-validator-key-in-vault.sh
#
# Idempotent in the sense that re-running with the same input just
# rewrites the KV entry. Re-running with a NEW key (e.g. after
# reregister) invalidates the old key.
#
# Usage:
#   source munchbox-env.sh
#   <pem-source> | infrastructure/scripts/store-validator-key-in-vault.sh [--vault-path <path>]
#
# Default --vault-path is secret/cinc/validator-key. Override to match
# your bootstrap module's chef_validator_vault_{mount,name} config.
# -------------------------------------------------------------------------------
set -euo pipefail

VAULT_PATH="secret/cinc/validator"
VAULT_FIELD="pem"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault-path) VAULT_PATH="$2"; shift 2 ;;
    --vault-field) VAULT_FIELD="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^# ---/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

for var in VAULT_ADDR VAULT_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is empty -- did you source munchbox-env.sh?" >&2
    exit 1
  fi
done

command -v vault >/dev/null || { echo "error: vault CLI not on PATH" >&2; exit 1; }

if [[ -t 0 ]]; then
  echo "error: no PEM on stdin. Pipe the validator key in. See header for examples." >&2
  exit 1
fi

# --- Read stdin into a temp file; trap wipes it on exit regardless. ---
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
PEM_FILE="$WORKDIR/validator.pem"
install -m 0600 /dev/null "$PEM_FILE"
cat > "$PEM_FILE"

if ! grep -q '^-----BEGIN.*PRIVATE KEY-----' "$PEM_FILE"; then
  echo "error: input doesn't look like a PEM private key (no BEGIN line)" >&2
  exit 1
fi

vault kv put "$VAULT_PATH" \
  "$VAULT_FIELD=@${PEM_FILE}" \
  notes="Stored $(date -u +%Y-%m-%dT%H:%M:%SZ) by store-validator-key-in-vault.sh" \
  >/dev/null

echo "stored validator key at $VAULT_PATH (field: $VAULT_FIELD)"
