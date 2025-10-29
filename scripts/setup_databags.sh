#!/usr/bin/env bash
# ==============================================================================
# scripts/setup_databags.sh — Regenerate secret, replace data bags, optional encrypt
#
# What it does (by default):
#   - Re-generates ./chef/encrypted_data_bag_secret (0600)
#   - Overwrites plaintext JSON templates for consul/nomad/vault with placeholders
#   - Optionally generates fresh base64 gossip keys (--gen-keys)
#   - Optionally encrypts all items in place via ./scripts/bagx.sh (--encrypt)
#
# Run from repo root.
#
# Usage:
#   ./scripts/setup_databags.sh                # regen secret + write plaintexts
#   ./scripts/setup_databags.sh --gen-keys     # also fill gossip keys automatically
#   ./scripts/setup_databags.sh --encrypt      # after editing, encrypt all in place
#   ./scripts/setup_databags.sh --keep-secret  # DO NOT regenerate the secret
#
# Notes:
# - This intentionally OVERWRITES any existing plaintext data bag JSONs for:
#       consul/{agent,management,gossip,agent_ca,nomad_server,nomad_client}
#       nomad/{gossip,management}
#       vault/vault_token
# - It leaves other bags (e.g., infra_certs/ssl, pia_vpn/wg, nomad/deploy) untouched.
# ==============================================================================

set -euo pipefail

SECRET="./chef/encrypted_data_bag_secret"
BAGX="./scripts/bagx.sh"

# Items we intentionally replace
declare -a ITEMS=(
  "consul/agent"
  "consul/management"
  "consul/gossip"
  "consul/agent_ca"
  "consul/nomad_server"
  "consul/nomad_client"
  "nomad/gossip"
  "nomad/management"
  "vault/vault_token"
)

DO_ENCRYPT=0
KEEP_SECRET=0
GEN_KEYS=0

for arg in "$@"; do
  case "$arg" in
    --encrypt) DO_ENCRYPT=1 ;;
    --keep-secret) KEEP_SECRET=1 ;;
    --gen-keys) GEN_KEYS=1 ;;
    *)
      echo "usage: $0 [--gen-keys] [--encrypt] [--keep-secret]" >&2
      exit 2
      ;;
  esac
done

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found" >&2; exit 1; }; }

ensure_dirs() {
  [[ -d ./chef ]] || { echo "ERROR: run from repo root; ./chef not found" >&2; exit 1; }
  mkdir -p ./chef/data_bags
}

regen_secret() {
  require openssl
  umask 177
  mkdir -p "$(dirname "$SECRET")"
  openssl rand -base64 32 > "$SECRET"
  chmod 600 "$SECRET"
  echo "Wrote new secret: $SECRET (mode 0600)."
  cat <<'EOF'
NOTE: Your previous encrypted data bags cannot be decrypted with this new secret.
      Recreate/re-encrypt as needed (this script is doing that for the listed items).
EOF
}

gen_gossip_key() { require openssl; openssl rand -base64 32; }

# -------------------------- Payload builders --------------------------
consul_agent() { cat <<'JSON'
{
  "id": "agent",
  "token": "CHANGE_ME_CONSUL_AGENT_TOKEN"
}
JSON
}

consul_management() { cat <<'JSON'
{
  "id": "management",
  "token": "CHANGE_ME_CONSUL_MANAGEMENT_TOKEN",
  "SecretID": ""
}
JSON
}

consul_gossip() {
  local key="BASE64_32BYTE_SERF_KEY_CHANGE_ME"
  [[ $GEN_KEYS -eq 1 ]] && key="$(gen_gossip_key)"
  cat <<JSON
{
  "id": "gossip",
  "encrypt": "${key}"
}
JSON
}

consul_agent_ca() { cat <<'JSON'
{
  "id": "agent_ca",
  "cert": "-----BEGIN CERTIFICATE-----\nPASTE_CA_CERT_PEM_HERE\n-----END CERTIFICATE-----\n",
  "key": "-----BEGIN RSA PRIVATE KEY-----\nPASTE_CA_KEY_PEM_HERE\n-----END RSA PRIVATE KEY-----\n"
}
JSON
}

consul_nomad_server() { cat <<'JSON'
{
  "id": "nomad_server",
  "token": "CHANGE_ME_NOMAD_SERVER_CONSUL_TOKEN"
}
JSON
}

consul_nomad_client() { cat <<'JSON'
{
  "id": "nomad_client",
  "token": "CHANGE_ME_NOMAD_CLIENT_CONSUL_TOKEN"
}
JSON
}

nomad_gossip() {
  local key="BASE64_32BYTE_NOMAD_GOSSIP_KEY_CHANGE_ME"
  [[ $GEN_KEYS -eq 1 ]] && key="$(gen_gossip_key)"
  cat <<JSON
{
  "id": "gossip",
  "encrypt": "${key}"
}
JSON
}

nomad_management() { cat <<'JSON'
{
  "id": "management",
  "secret_id": "CHANGE_ME_NOMAD_MANAGEMENT_TOKEN"
}
JSON
}

vault_vault_token() { cat <<'JSON'
{
  "id": "vault_token",
  "token": "s.CHANGE_ME_VAULT_TOKEN"
}
JSON
}

write_json() {
  local bag="$1" item="$2" payload="$3"
  local dir="./chef/data_bags/${bag}"
  local path="${dir}/${item}.json"
  mkdir -p "$dir"
  printf "%s\n" "${payload}" > "$path"
  echo "Wrote: $path"
}

encrypt_all() {
  [[ -x "$BAGX" ]] || { echo "ERROR: $BAGX not found or not executable." >&2; exit 1; }
  for spec in "${ITEMS[@]}"; do
    local bag="${spec%%/*}" item="${spec##*/}"
    local path="./chef/data_bags/${bag}/${item}.json"
    if [[ -f "$path" ]]; then
      "$BAGX" encrypt "$path"
    else
      echo "WARN: missing (skip): $path" >&2
    fi
  done
  echo "Encryption complete."
}

# ------------------------------- Main -------------------------------
ensure_dirs
if [[ $KEEP_SECRET -eq 0 ]]; then regen_secret; else echo "Keeping existing secret at $SECRET"; fi

# Always overwrite these items with fresh plaintext templates
write_json consul agent         "$(consul_agent)"
write_json consul management    "$(consul_management)"
write_json consul gossip        "$(consul_gossip)"
write_json consul agent_ca      "$(consul_agent_ca)"
write_json consul nomad_server  "$(consul_nomad_server)"
write_json consul nomad_client  "$(consul_nomad_client)"
write_json nomad  gossip        "$(nomad_gossip)"
write_json nomad  management    "$(nomad_management)"
write_json vault  vault_token   "$(vault_vault_token)"

if [[ $DO_ENCRYPT -eq 1 ]]; then
  encrypt_all
else
  cat <<'EOF'

NEXT STEPS
----------
1) Edit each file under ./chef/data_bags/<bag>/<item>.json:
     - Replace CHANGE_ME_* placeholders with real values
     - If you didn't pass --gen-keys, set base64(32B) gossip keys (openssl rand -base64 32)
     - Paste correct PEM contents for consul/agent_ca (keep the BEGIN/END blocks)

2) Encrypt in place when ready:
     ./scripts/setup_databags.sh --encrypt

3) Verify by decrypting one, e.g.:
     ./scripts/bagx.sh decrypt ./chef/data_bags/consul/agent.json

EOF
fi

