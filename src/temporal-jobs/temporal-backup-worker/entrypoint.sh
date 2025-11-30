#!/bin/bash
# ===========================================================================
# Temporal Backup Container Entrypoint
# ===========================================================================
#
# Project: Munchbox
# Purpose: Switch between worker and trigger execution modes
#
# This script serves as the container entrypoint, allowing a single image
# to function as either a long-running worker or a one-shot trigger based
# on the command argument.
#
# Usage:
#   worker  - Start the temporal-backup-worker service
#   trigger - Execute temporal-backup-trigger once and exit
#
# Environment variables:
#   TEMPORAL_ADDRESS     - Temporal server endpoint (default: localhost:7233)
#   NOMAD_TOKEN          - Nomad authentication token
#   CONSUL_HTTP_TOKEN    - Consul authentication token
#   BAO_ADDR             - OpenBao server address
#   BAO_TOKEN            - OpenBao authentication token
#   BAO_SKIP_VERIFY      - Skip TLS verification (default: true)
#
# Author: Alex Freidah
# ===========================================================================

set -e

MODE="${1:-worker}"

case "$MODE" in
    worker)
        echo "Starting Temporal backup worker..."
        exec /usr/local/bin/temporal-backup-worker
        ;;
    trigger)
        echo "Triggering backup workflow..."
        exec /usr/local/bin/temporal-backup-trigger
        ;;
    *)
        echo "Error: Invalid mode '$MODE'"
        echo "Usage: $0 {worker|trigger}"
        exit 1
        ;;
esac
