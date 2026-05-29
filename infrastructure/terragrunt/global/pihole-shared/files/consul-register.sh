#!/bin/bash
# -----------------------------------------------------------------------
# Consul Service Registration Script
#
# Project: Munchbox / Author: Alex Freidah
# -----------------------------------------------------------------------

set -euo pipefail

CONSUL_ADDR="http://192.168.68.61:8500"
REGISTER_DIR="/etc/consul-register"

register_service() {
    local service_file="$1"
    echo "Registering $(basename "$service_file")..."

    curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d @"$service_file" \
        "$CONSUL_ADDR/v1/catalog/register" || {
        echo "Failed to register $service_file"
        return 1
    }
}

# Register all service definitions
for service_json in "$REGISTER_DIR"/*.json; do
    if [ -f "$service_json" ]; then
        register_service "$service_json"
    fi
done

echo "Service registration complete for $(hostname -s)"
