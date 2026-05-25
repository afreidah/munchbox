#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# bootstrap-cinc-node.sh
#
# One command to bring a greenfield node fully under cinc management:
#   1. install /etc/cinc/encrypted_data_bag_secret on the node
#      (delegates to install-data-bag-secret.sh)
#   2. mint encrypted vault_agent/<node> data bag item on cinc-server
#      (delegates to upload-vault-agent-data-bag.sh)
#   3. install cinc-client via the omnibus installer
#   4. drop /etc/cinc/{validation.pem, trusted_certs/cinc-server.crt,
#      client.rb, first-boot.json}
#   5. run `cinc-client -j first-boot.json` -- registers the node, applies
#      the run_list, takes over management
#
# After this script, the cinc_client cookbook (via role[base] -> role[cinc_client])
# manages /etc/cinc/client.rb on every subsequent converge. The two helper
# scripts remain useful for standalone rotation later:
#   - install-data-bag-secret.sh   (re-deliver the data-bag secret on rotation)
#   - upload-vault-agent-data-bag.sh (re-upload AppRole creds on rotation)
#
# Usage:
#   source munchbox-env.sh
#   infrastructure/cinc/scripts/bootstrap-cinc-node.sh <ssh-target> <node-name> <role>
#
# Example:
#   ./bootstrap-cinc-node.sh ubuntu@oracle-arm-1 oraclearm1 oracle_arm_1
#
# Pre-reqs (you do these once before running this script):
#   - secret_id for <node-name> exists at secret/chef-approle/secret-ids/<node-name> in Vault
#   - <role>.rb is uploaded to cinc-server (knife role from file)
#   - any cookbooks the role depends on are uploaded
#
# Vault paths consumed:
#   secret/cinc/validator                       -- field 'pem'
#   secret/cinc/server-cert                     -- field 'pem'
#   secret/cinc/encrypted_data_bag_secret       -- via helper script
#   secret/chef-approle/role-id                 -- via helper script
#   secret/chef-approle/secret-ids/<node-name>  -- via helper script
# -------------------------------------------------------------------------------
set -euo pipefail

TARGET="${1:-}"
NODE="${2:-}"
ROLE="${3:-}"
if [[ -z "$TARGET" || -z "$NODE" || -z "$ROLE" ]]; then
  echo "usage: $0 <ssh-target> <node-name> <role>" >&2
  echo "  e.g.: $0 ubuntu@oracle-arm-1 oraclearm1 oracle_arm_1" >&2
  exit 1
fi

for var in VAULT_ADDR VAULT_TOKEN; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is empty -- did you source munchbox-env.sh?" >&2
    exit 1
  fi
done

for cmd in vault ssh scp knife; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd not on PATH" >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CINC_SERVER_URL='https://cinc-server.munchbox.cc/organizations/munchbox'
VALIDATOR_CLIENT_NAME='munchbox-validator'

# --- Skip sudo when SSH user is root. Minimal proxmox installs don't ship sudo and we SSH as root there; oracle/ubuntu nodes still need it. ---
SSH_USER="${TARGET%%@*}"
if [[ "$TARGET" == *"@"* && "$SSH_USER" == "root" ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

# -------------------------------------------------------------------------------
# Step 1 -- data-bag decryption secret on the node
# -------------------------------------------------------------------------------
echo "==> [1/5] staging /etc/cinc/encrypted_data_bag_secret on $TARGET"
"$SCRIPT_DIR/install-data-bag-secret.sh" "$TARGET"

# -------------------------------------------------------------------------------
# Step 2 -- AppRole creds into the encrypted vault_agent data bag
# -------------------------------------------------------------------------------
echo
echo "==> [2/5] uploading encrypted vault_agent/$NODE to cinc-server"
"$SCRIPT_DIR/upload-vault-agent-data-bag.sh" "$NODE"

# -------------------------------------------------------------------------------
# Step 3 -- install cinc-client via omnibus (idempotent)
#
# Pin to the same version as the cinc_client cookbook (attributes/default.rb)
# so a fresh node bootstrapped today doesn't drift from the cookbook between
# this step and first converge. If you bump the cookbook pin, bump CINC_VERSION
# here in the same commit.
# -------------------------------------------------------------------------------
CINC_VERSION='19.3.14'
echo
echo "==> [3/5] installing cinc-client $CINC_VERSION on $TARGET"
ssh "$TARGET" "$SUDO bash -c 'if command -v cinc-client >/dev/null; then echo \"cinc already installed: \$(cinc-client --version)\"; else curl -L https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc -v $CINC_VERSION; fi'"

# -------------------------------------------------------------------------------
# Step 4 -- pull validator + cinc-server cert from Vault, stage on node, write client.rb + first-boot.json
# -------------------------------------------------------------------------------
echo
echo "==> [4/5] staging validator + trusted cert + client.rb + first-boot.json"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

VALIDATOR_FILE="$WORKDIR/validation.pem"
CINC_CRT_FILE="$WORKDIR/cinc-server.crt"
FIRSTBOOT_FILE="$WORKDIR/first-boot.json"
install -m 0600 /dev/null "$VALIDATOR_FILE"
install -m 0600 /dev/null "$CINC_CRT_FILE"
install -m 0644 /dev/null "$FIRSTBOOT_FILE"

vault kv get -field=pem secret/cinc/validator   > "$VALIDATOR_FILE"
vault kv get -field=pem secret/cinc/server-cert > "$CINC_CRT_FILE"

# --- first-boot.json carries the run_list so the very first cinc-client run applies the role; no race between node creation and `knife node run_list set`. ---
cat > "$FIRSTBOOT_FILE" <<JSON
{
  "run_list": ["role[$ROLE]"]
}
JSON

scp -q "$VALIDATOR_FILE" "$CINC_CRT_FILE" "$FIRSTBOOT_FILE" "$TARGET:/tmp/"

ssh "$TARGET" "$SUDO bash -c '
  set -e
  install -d -m 0755 -o root -g root /etc/cinc /etc/cinc/trusted_certs /var/log/cinc
  install -m 0600 -o root -g root /tmp/validation.pem  /etc/cinc/validation.pem
  install -m 0644 -o root -g root /tmp/cinc-server.crt /etc/cinc/trusted_certs/cinc-server.crt
  install -m 0644 -o root -g root /tmp/first-boot.json /etc/cinc/first-boot.json
  rm -f /tmp/validation.pem /tmp/cinc-server.crt /tmp/first-boot.json

  cat > /etc/cinc/client.rb <<EOF
# Bootstrap client.rb -- cinc_client::configure recipe will manage this file
# on every converge after the first run.
chef_server_url        \"$CINC_SERVER_URL\"
validation_client_name \"$VALIDATOR_CLIENT_NAME\"
validation_key         \"/etc/cinc/validation.pem\"
client_key             \"/etc/cinc/client.pem\"
trusted_certs_dir      \"/etc/cinc/trusted_certs\"
node_name              \"$NODE\"
log_level              :info
log_location           \"/var/log/cinc/client.log\"
EOF
'"

# -------------------------------------------------------------------------------
# Step 5 -- first converge under role[$ROLE], then persist the run_list on cinc-server
# -------------------------------------------------------------------------------
echo
echo "==> [5/5] first cinc-client run on $TARGET (registers + applies role[$ROLE])"
ssh "$TARGET" "$SUDO cinc-client -j /etc/cinc/first-boot.json" || true

# --- `-j first-boot.json` only sets the run_list for that single run; persist it on cinc-server so subsequent runs (timer-driven or manual `cinc-client` without -j) keep applying the role ---
echo
echo "==> persisting run_list on cinc-server (knife node run_list set $NODE 'role[$ROLE]')"
knife node run_list set "$NODE" "role[$ROLE]" >/dev/null

echo
echo "bootstrap complete: $NODE registered, role[$ROLE] applied + persisted"
