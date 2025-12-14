#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Bagx - Chef Encrypted Data Bag Tool
#
# Project: Munchbox / Author: Alex Freidah
#
# Encrypts and decrypts Chef data bag items using the repository secret key.
# Run from repo root. Deprecated in favor of Vault secrets.
#
# Usage:
#   ./scripts/bagx.sh decrypt path/to/item.json
#   ./scripts/bagx.sh encrypt path/to/item.json
# -------------------------------------------------------------------------------

set -euo pipefail

SECRET="./chef/encrypted_data_bag_secret"

usage() {
  echo "usage: $0 {encrypt|decrypt} path/to/file.json" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
ACTION="$1"
FILE="$2"

[[ -f "$SECRET" ]] || { echo "ERROR: secret not found at $SECRET" >&2; exit 1; }
[[ -f "$FILE"   ]] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }

case "$ACTION" in
  decrypt)
    chef exec ruby -rjson -rchef/encrypted_data_bag_item -e '
enc  = JSON.parse(File.read(ARGV[0]))
sec  = Chef::EncryptedDataBagItem.load_secret(ARGV[1])
plain = Chef::EncryptedDataBagItem.new(enc, sec).to_hash
puts JSON.pretty_generate(plain)
' "$FILE" "$SECRET"
    ;;

  encrypt)
    tmp="$(mktemp "${FILE}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT

    chef exec ruby -rjson -rchef/encrypted_data_bag_item -e '
plain = JSON.parse(File.read(ARGV[0]))
if plain.is_a?(Hash) && %w[encrypted_data iv auth_tag version cipher].all? { |k| plain.key?(k) }
  abort("Refusing to encrypt: file already looks encrypted")
end
sec = Chef::EncryptedDataBagItem.load_secret(ARGV[1])
enc = Chef::EncryptedDataBagItem.encrypt_data_bag_item(plain, sec)
File.write(ARGV[2], JSON.pretty_generate(enc))
' "$FILE" "$SECRET" "$tmp"

    mv -f "$tmp" "$FILE"
    trap - EXIT
    echo "Encrypted: $FILE"
    ;;

  *)
    usage
    ;;
esac

