#!/bin/bash

# -----------------------------------------------------------------------
# Munchbox Nomad Service Deployment Script
# -----------------------------------------------------------------------

set -e

REGISTRY="munchbox"
PACK="nomad-service"
JOBS_DIR="./jobs"
ACTION="${1:-plan}"
JOB_FILE="${2}"

# Ensure registry is registered
if ! nomad-pack registry list | grep -q "^$REGISTRY"; then
  echo "Registering Munchbox pack registry..."
  nomad-pack registry add "$REGISTRY" github.com/afreidah/nomad-pack-registry
fi

if [ -z "$JOB_FILE" ] || [ "$JOB_FILE" = "all" ]; then
  for job_file in "$JOBS_DIR"/*.hcl; do
    job_name=$(basename "$job_file" .hcl)
    echo ""
    echo "=========================================="
    echo "Processing: $job_name"
    echo "=========================================="
    
    nomad-pack "$ACTION" "$PACK" \
      --registry "$REGISTRY" \
      -f "$job_file"
  done
else
  nomad-pack "$ACTION" "$PACK" \
    --registry "$REGISTRY" \
    -f "$JOBS_DIR/$JOB_FILE.hcl"
fi
