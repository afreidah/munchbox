#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# prepare-chef-bootstrap.sh
#
# One-shot pre-provision step for a new chef-managed node. Runs the three
# things that MUST exist on Vault + chef-server BEFORE the node boots and
# cloud-init tries to converge:
#
#   1. Mint an AppRole secret_id from auth/chef-approle/role/chef-managed-node
#      and store it at secret/chef-approle/secret-ids/<node>.
#   2. Build the encrypted vault_agent data-bag item for <node> + upload
#      it to chef-server (wraps upload-vault-agent-data-bag.sh).
#   3. Upload the per-node chef node object from
#      infrastructure/cinc/nodes/<node>.rb (carries run_list + tags +
#      normal attrs).
#
# After this completes, the bootstrap cloud-init can successfully fetch
# its vault-agent creds via the encrypted data bag, and cinc-client's
# first converge picks up the pre-uploaded run_list.
#
# Usage:
#   source munchbox-env.sh
#   infrastructure/scripts/prepare-chef-bootstrap.sh <chef-node-name>
#
# Examples:
#   ./prepare-chef-bootstrap.sh oraclearm5
#   ./prepare-chef-bootstrap.sh haproxy01
#
# Idempotent -- safe to re-run if anything failed mid-way. The node-object
# upload is always a re-upload; the secret_id mint always generates a fresh
# value (and rotates the Vault KV entry as a side effect).
# -------------------------------------------------------------------------------
set -euo pipefail

NODE="${1:-}"
if [[ -z "$NODE" ]]; then
  echo "usage: $0 <chef-node-name>   e.g. oraclearm5 or haproxy01" >&2
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_FILE="${SCRIPT_DIR}/../cinc/nodes/${NODE}.rb"

# --- 1. Mint a fresh AppRole secret_id and stash it in Vault for the node. ---
echo "[1/3] Minting chef-approle secret_id for $NODE..."
SECRET_ID="$(vault write -force -field=secret_id auth/chef-approle/role/chef-managed-node/secret-id)"
vault kv put "secret/chef-approle/secret-ids/$NODE" \
  secret_id="$SECRET_ID" \
  notes="Minted $(date -u +%Y-%m-%dT%H:%M:%SZ) by prepare-chef-bootstrap.sh for node $NODE" \
  >/dev/null
echo "      stored at secret/chef-approle/secret-ids/$NODE"

# --- 2. Build the encrypted vault_agent data-bag item + upload it. ---
echo "[2/3] Uploading encrypted vault_agent data-bag item for $NODE..."
"${SCRIPT_DIR}/upload-vault-agent-data-bag.sh" "$NODE"

# --- 3. Upload the per-node chef node object. ---
echo "[3/3] Uploading chef node object for $NODE..."
if [[ ! -f "$NODE_FILE" ]]; then
  echo "error: no node file found at $NODE_FILE" >&2
  echo "       create the per-node file first, then re-run." >&2
  exit 1
fi
knife node from file "$NODE_FILE"
echo "      uploaded $NODE_FILE"

echo
echo "READY. Pre-provision steps complete for $NODE."
echo "Next: cd to the terragrunt node dir and run \`terragrunt apply\`."
