#!/bin/bash
# -------------------------------------------------------------------------------
# Update Consul Anonymous Token Policy
#
# This script updates the Consul anonymous token (used for DNS queries) to use
# the specified ACL policy.
#
# Usage:
#   ./update-anonymous-token.sh <policy-name>
#
# Example:
#   ./update-anonymous-token.sh anonymous-dns-policy
# -------------------------------------------------------------------------------

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONSUL_SERVER="mccoy"
ANONYMOUS_TOKEN_ID="00000000-0000-0000-0000-000000000002"

# -------------------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------------------

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 <policy-name>"
    echo
    echo "Updates the Consul anonymous token to use the specified policy."
    echo
    echo "Example:"
    echo "  $0 anonymous-dns-policy"
    exit 1
}

# -------------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------------

# Check arguments
if [[ $# -ne 1 ]]; then
    log_error "Policy name is required"
    usage
fi

POLICY_NAME="$1"

log_info "Updating Consul anonymous token with policy: ${POLICY_NAME}"
log_info "Connecting to Consul server: ${CONSUL_SERVER}"

# Execute the update command via SSH
if ssh root@"${CONSUL_SERVER}" "consul acl token update -id ${ANONYMOUS_TOKEN_ID} -policy-name ${POLICY_NAME}"; then
    log_info "✓ Successfully updated anonymous token with policy: ${POLICY_NAME}"
    log_info "DNS queries will now use this policy for access control"
else
    log_error "Failed to update anonymous token"
    exit 1
fi
