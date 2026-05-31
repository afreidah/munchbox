#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# upload-vault-agent-data-bag.sh
#
# Pulls a chef node's Vault AppRole creds out of Vault, encrypts them with
# the shared data-bag secret (also pulled from Vault), and uploads the
# resulting encrypted item to the cinc-server.
#
# Vault is the source of truth; nothing derived ever lands on disk
# permanently or in git. All tempfiles live under a per-run mktemp dir
# that's wiped on exit.
#
# Usage:
#   source munchbox-env.sh
#   infrastructure/scripts/upload-vault-agent-data-bag.sh <node-name>
#
# Vault paths consumed:
#   secret/cinc/encrypted_data_bag_secret    -- field 'value'
#   secret/chef-approle/role-id              -- field 'role_id'
#   secret/chef-approle/secret-ids/<node>    -- field 'secret_id'
# -------------------------------------------------------------------------------
set -euo pipefail

NODE="${1:-}"
if [[ -z "$NODE" ]]; then
  echo "usage: $0 <node-name>" >&2
  exit 1
fi

for var in VAULT_ADDR VAULT_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is empty -- did you source munchbox-env.sh?" >&2
    exit 1
  fi
done

command -v vault >/dev/null || { echo "error: vault CLI not on PATH" >&2; exit 1; }
command -v knife >/dev/null || { echo "error: knife CLI not on PATH" >&2; exit 1; }

# --- All derived material lives here; trap wipes it no matter how we exit ---
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

SECRET_FILE="$WORKDIR/secret"
ITEM_FILE="$WORKDIR/$NODE.json"

# --- Restrictive perms before content lands ---
install -m 0600 /dev/null "$SECRET_FILE"
install -m 0600 /dev/null "$ITEM_FILE"

vault kv get -field=value secret/cinc/encrypted_data_bag_secret > "$SECRET_FILE"

ROLE_ID="$(vault kv get -field=role_id secret/chef-approle/role-id)"
SECRET_ID="$(vault kv get -field=secret_id "secret/chef-approle/secret-ids/$NODE")"

# --- Plaintext item -- knife will encrypt + upload it next ---
cat > "$ITEM_FILE" <<JSON
{
  "id":        "$NODE",
  "role_id":   "$ROLE_ID",
  "secret_id": "$SECRET_ID"
}
JSON

# --- Idempotent: create the bag if missing, then push the encrypted item ---
knife data bag create vault_agent 2>/dev/null || true
knife data bag from file vault_agent "$ITEM_FILE" --secret-file "$SECRET_FILE"

echo "uploaded encrypted vault_agent/$NODE to cinc-server"
