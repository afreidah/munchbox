#!/bin/bash
# -------------------------------------------------------------------------------
# Consul Stale Service Cleanup
#
# Project: Munchbox / Author: Alex Freidah
#
# Removes stale Consul service registrations that no longer have running Nomad
# allocations. Compares service IDs against active allocations and deregisters
# orphaned entries via the catalog API.
#
# Usage:
#   consul-cleanup-stale.sh <service-name>    # Clean specific service
#   consul-cleanup-stale.sh --all             # Clean all services
#   consul-cleanup-stale.sh --critical        # Clean all critical services
# -------------------------------------------------------------------------------

set -euo pipefail

CONSUL_HOST="${CONSUL_HOST:-192.168.68.61}"
CONSUL_PORT="${CONSUL_PORT:-8500}"
DRY_RUN="${DRY_RUN:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <service-name|--all|--critical>"
    echo ""
    echo "Options:"
    echo "  <service-name>  Clean stale registrations for specific service"
    echo "  --all           Clean all services with stale registrations"
    echo "  --critical      Clean only services in critical state"
    echo ""
    echo "Environment:"
    echo "  CONSUL_HOST     Consul server (default: 192.168.68.61)"
    echo "  DRY_RUN=true    Show what would be deleted without deleting"
    exit 1
}

consul_api() {
    local endpoint="$1"
    ssh root@"${CONSUL_HOST}" "curl -s http://127.0.0.1:${CONSUL_PORT}${endpoint}" 2>/dev/null
}

consul_deregister() {
    local node="$1"
    local service_id="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would deregister: ${node}/${service_id}"
        return 0
    fi

    local payload="{\"Datacenter\": \"munchbox\", \"Node\": \"${node}\", \"ServiceID\": \"${service_id}\"}"
    local result
    result=$(ssh root@"${CONSUL_HOST}" "curl -s -X PUT -d '${payload}' http://127.0.0.1:${CONSUL_PORT}/v1/catalog/deregister" 2>/dev/null)

    if [[ "$result" == "true" ]]; then
        echo -e "${GREEN}[REMOVED]${NC} ${node}/${service_id}"
        return 0
    else
        echo -e "${RED}[FAILED]${NC} ${node}/${service_id}: ${result}"
        return 1
    fi
}

get_running_alloc_ids() {
    # Get all running allocation IDs from Nomad (first 8 chars to match service ID format)
    nomad operator api /v1/allocations 2>/dev/null | \
        jq -r '.[] | select(.ClientStatus == "running") | .ID[:8]' 2>/dev/null | \
        sort -u
}

cleanup_service() {
    local service="$1"
    local stale_count=0
    local running_allocs

    # Get running allocation IDs
    running_allocs=$(get_running_alloc_ids)

    # Get all instances of this service
    local instances
    instances=$(consul_api "/v1/health/service/${service}" | jq -r '.[] | "\(.Node.Node)|\(.Service.ID)"' 2>/dev/null)

    if [[ -z "$instances" ]]; then
        echo "No instances found for service: ${service}"
        return 0
    fi

    while IFS='|' read -r node service_id; do
        [[ -z "$node" || -z "$service_id" ]] && continue

        # Check if this is a Nomad-registered service
        if [[ "$service_id" == _nomad-task-* ]]; then
            # Extract allocation ID (first 8 chars after _nomad-task-)
            local alloc_id
            alloc_id=$(echo "$service_id" | sed 's/_nomad-task-\([a-f0-9-]*\)-.*/\1/' | cut -c1-8)

            # Check if allocation is still running
            if ! echo "$running_allocs" | grep -q "^${alloc_id}"; then
                consul_deregister "$node" "$service_id"
                ((stale_count++)) || true
            fi
        fi
    done <<< "$instances"

    if [[ $stale_count -eq 0 ]]; then
        echo -e "${GREEN}[OK]${NC} ${service}: no stale registrations"
    else
        echo -e "${YELLOW}[CLEANED]${NC} ${service}: removed ${stale_count} stale registration(s)"
    fi
}

cleanup_critical() {
    echo "Finding services in critical state..."

    local critical
    critical=$(consul_api "/v1/health/state/critical" | jq -r '.[] | "\(.Node)|\(.ServiceName)|\(.ServiceID)"' 2>/dev/null)

    if [[ -z "$critical" ]]; then
        echo -e "${GREEN}[OK]${NC} No critical services found"
        return 0
    fi

    local count=0
    while IFS='|' read -r node service_name service_id; do
        [[ -z "$node" || -z "$service_id" ]] && continue

        # Only clean Nomad-registered services
        if [[ "$service_id" == _nomad-task-* ]]; then
            consul_deregister "$node" "$service_id"
            ((count++)) || true
        fi
    done <<< "$critical"

    echo -e "${YELLOW}[DONE]${NC} Removed ${count} critical service(s)"
}

cleanup_all() {
    echo "Scanning all services for stale registrations..."

    local services
    services=$(consul_api "/v1/catalog/services" | jq -r 'keys[]' 2>/dev/null)

    for service in $services; do
        # Skip consul itself
        [[ "$service" == "consul" ]] && continue
        cleanup_service "$service"
    done
}

# Main
[[ $# -lt 1 ]] && usage

case "$1" in
    --all)
        cleanup_all
        ;;
    --critical)
        cleanup_critical
        ;;
    --help|-h)
        usage
        ;;
    *)
        cleanup_service "$1"
        ;;
esac
