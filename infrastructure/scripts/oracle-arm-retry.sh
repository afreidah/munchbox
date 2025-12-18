#!/bin/bash
# -------------------------------------------------------------------------------
# Oracle ARM Instance Retry Script
#
# Project: Munchbox / Author: Alex Freidah
#
# Continuously attempts to create an Oracle ARM instance until successful.
# ARM capacity on Oracle Free Tier is very limited - this script retries
# automatically until capacity becomes available.
#
# Usage: ./oracle-arm-retry.sh <node-name> [interval_seconds]
#   node-name: Name of the node directory (e.g., oracle-arm-1)
#   interval_seconds: Time between retries (default: 60)
# -------------------------------------------------------------------------------

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <node-name> [interval_seconds]"
    echo "Example: $0 oracle-arm-1 60"
    exit 1
fi

NODE_NAME="${1}"
RETRY_INTERVAL="${2:-60}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAGRUNT_DIR="$REPO_ROOT/infrastructure/terragrunt/oci/$NODE_NAME"
LOG_FILE="/tmp/oracle-arm-retry-${NODE_NAME}.log"
ATTEMPT=0

# Source munchbox env for vault/consul tokens
if [[ -f "$REPO_ROOT/munchbox-env.sh" ]]; then
    source "$REPO_ROOT/munchbox-env.sh"
fi

# Need the Consul bootstrap token for state locking
if [[ -z "${CONSUL_HTTP_TOKEN:-}" ]]; then
    echo "Getting Consul bootstrap token from Vault..."
    export CONSUL_HTTP_TOKEN=$(vault kv get -field=token secret/consul/bootstrap-token)
fi

echo "Oracle ARM Instance Retry Script (Terragrunt)"
echo "=============================================="
echo "Node: $NODE_NAME"
echo "Terragrunt dir: $TERRAGRUNT_DIR"
echo "Retry interval: ${RETRY_INTERVAL}s"
echo "Log file: $LOG_FILE"
echo ""

if [[ ! -d "$TERRAGRUNT_DIR" ]]; then
    echo "Error: Directory $TERRAGRUNT_DIR does not exist"
    exit 1
fi

cd "$TERRAGRUNT_DIR"

while true; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempt #$ATTEMPT: Creating ARM instance..."

    if terragrunt apply -auto-approve > "$LOG_FILE" 2>&1; then
        if grep -q "Apply complete! Resources: 1 added" "$LOG_FILE" || grep -q "Apply complete! Resources: [0-9]* added" "$LOG_FILE"; then
            echo ""
            echo "SUCCESS! ARM instance created on attempt #$ATTEMPT"
            echo ""
            echo "Output:"
            terragrunt output 2>/dev/null || true
            echo ""
            echo "Don't forget to:"
            echo "  1. Add WireGuard peer to stabler"
            echo "  2. Run ansible add-node playbook"
            break
        fi
    fi

    if grep -q "Out of host capacity" "$LOG_FILE"; then
        echo "  -> No capacity available. Waiting ${RETRY_INTERVAL}s before retry..."
        sleep "$RETRY_INTERVAL"
    elif grep -q "Apply complete! Resources: 0 added" "$LOG_FILE"; then
        echo "  -> Instance already exists or no changes needed."
        terragrunt output 2>/dev/null || true
        break
    else
        echo "  -> Unexpected error. Check $LOG_FILE for details."
        echo "  -> Last 30 lines:"
        tail -30 "$LOG_FILE"
        exit 1
    fi
done
