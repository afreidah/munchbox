#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Rotate Forgejo Access Token
#
# Project: Munchbox / Author: Alex Freidah
#
# Rotates a Forgejo personal access token by creating a new one and deleting
# the old one. Outputs the new token for storage in a secure location.
#
# Usage:
#   ./rotate-forgejo-token.sh
#
# Environment variables:
#   FORGEJO_URL      - Forgejo instance URL (default: https://git.munchbox.cc)
#   FORGEJO_USER     - Forgejo username (default: alex)
#   FORGEJO_TOKEN    - Current access token (required, or reads from stdin)
#   TOKEN_NAME       - Name for the new token (default: munchbox-api-<timestamp>)
# -------------------------------------------------------------------------------

set -euo pipefail

FORGEJO_URL="${FORGEJO_URL:-https://git.munchbox.cc}"
FORGEJO_USER="${FORGEJO_USER:-alex}"
TOKEN_NAME="${TOKEN_NAME:-munchbox-api-$(date +%Y%m%d-%H%M%S)}"

# Get current token
if [[ -z "${FORGEJO_TOKEN:-}" ]]; then
    echo "Enter current Forgejo access token:" >&2
    read -rs FORGEJO_TOKEN
    echo >&2
fi

if [[ -z "$FORGEJO_TOKEN" ]]; then
    echo "Error: FORGEJO_TOKEN is required" >&2
    exit 1
fi

API_BASE="${FORGEJO_URL}/api/v1"

echo "Rotating Forgejo token for user: ${FORGEJO_USER}" >&2
echo "Forgejo URL: ${FORGEJO_URL}" >&2

# Step 1: List existing tokens to find the old one's ID
echo "Fetching existing tokens..." >&2
OLD_TOKENS=$(curl -sf -X GET \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    "${API_BASE}/users/${FORGEJO_USER}/tokens" 2>/dev/null) || {
    echo "Error: Failed to list tokens. Check your token and permissions." >&2
    exit 1
}

# Step 2: Create a new token with full scopes
echo "Creating new token: ${TOKEN_NAME}" >&2
NEW_TOKEN_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${TOKEN_NAME}\", \"scopes\": [\"all\"]}" \
    "${API_BASE}/users/${FORGEJO_USER}/tokens" 2>/dev/null) || {
    echo "Error: Failed to create new token." >&2
    exit 1
}

NEW_TOKEN=$(echo "$NEW_TOKEN_RESPONSE" | jq -r '.sha1')
NEW_TOKEN_ID=$(echo "$NEW_TOKEN_RESPONSE" | jq -r '.id')

if [[ -z "$NEW_TOKEN" || "$NEW_TOKEN" == "null" ]]; then
    echo "Error: Failed to extract new token from response" >&2
    echo "Response: $NEW_TOKEN_RESPONSE" >&2
    exit 1
fi

echo "New token created (ID: ${NEW_TOKEN_ID})" >&2

# Step 3: Find and delete old tokens (except the new one)
echo "Cleaning up old tokens..." >&2
OLD_TOKEN_IDS=$(echo "$OLD_TOKENS" | jq -r '.[].id')

for OLD_ID in $OLD_TOKEN_IDS; do
    if [[ "$OLD_ID" != "$NEW_TOKEN_ID" ]]; then
        OLD_NAME=$(echo "$OLD_TOKENS" | jq -r ".[] | select(.id == ${OLD_ID}) | .name")
        echo "  Deleting old token: ${OLD_NAME} (ID: ${OLD_ID})" >&2
        curl -sf -X DELETE \
            -H "Authorization: token ${NEW_TOKEN}" \
            "${API_BASE}/users/${FORGEJO_USER}/tokens/${OLD_ID}" 2>/dev/null || {
            echo "  Warning: Failed to delete token ${OLD_ID}" >&2
        }
    fi
done

# Step 4: Output the new token
echo "" >&2
echo "=============================================" >&2
echo "Token rotation complete!" >&2
echo "=============================================" >&2
echo "" >&2
echo "New token name: ${TOKEN_NAME}" >&2
echo "Store this token securely (e.g., in Vault or ~/.munchbox/forgejo-token)" >&2
echo "" >&2

# Output just the token to stdout (for piping to a file)
echo "$NEW_TOKEN"
