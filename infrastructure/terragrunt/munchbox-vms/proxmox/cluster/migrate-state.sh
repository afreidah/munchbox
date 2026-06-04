#!/bin/bash
# -----------------------------------------------------------------------------
# STATE MIGRATION SCRIPT
# -----------------------------------------------------------------------------
#
# Migrates Proxmox VM state from terraform/proxmox to terragrunt/proxmox/cluster
#
# Old state path: terraform/proxmox (Consul: terraform/proxmox)
# New state path: terragrunt/proxmox/cluster (Consul: terraform/munchbox/proxmox/cluster)
#
# Usage:
#   cd terragrunt/proxmox/cluster
#   ./migrate-state.sh
#
# -----------------------------------------------------------------------------

set -euo pipefail

CONSUL_ADDR="${CONSUL_HTTP_ADDR:-stabler:8500}"
OLD_CONSUL_PATH="terraform/proxmox"

echo "=== Proxmox State Migration ==="
echo ""

# Step 1: Initialize terragrunt
echo "[1/5] Initializing terragrunt..."
terragrunt init

# Step 2: Pull old state from Consul
echo "[2/5] Pulling old state from Consul ($OLD_CONSUL_PATH)..."
cd ../../../terraform/proxmox
OLD_STATE=$(terraform state pull)
cd - > /dev/null

if [ -z "$OLD_STATE" ] || [ "$OLD_STATE" == "{}" ]; then
  echo "ERROR: No state found"
  exit 1
fi

echo "Found $(echo "$OLD_STATE" | jq '.resources | length') resources"

# Step 3: Transform state - update resource addresses
echo "[3/5] Transforming state for new module structure..."

# Transform: proxmox_vm_qemu.vm["name"] -> module.vm["name"].proxmox_vm_qemu.this
NEW_STATE=$(echo "$OLD_STATE" | jq '
  .resources = [
    .resources[] |
    if .type == "proxmox_vm_qemu" and .name == "vm" then
      # Convert for_each resource to module instances
      .instances[] as $inst |
      {
        "module": ("module.vm[\"" + $inst.index_key + "\"]"),
        "mode": "managed",
        "type": "proxmox_vm_qemu",
        "name": "this",
        "provider": .provider,
        "instances": [{
          "schema_version": $inst.schema_version,
          "attributes": $inst.attributes,
          "sensitive_attributes": ($inst.sensitive_attributes // []),
          "private": ($inst.private // "")
        }]
      }
    else
      .
    end
  ] |
  .serial = (.serial + 1)
')

# Step 4: Push transformed state
echo "[4/5] Pushing transformed state to new location..."
echo "$NEW_STATE" | terragrunt state push -

# Step 5: Verify
echo "[5/5] Verifying migration..."
echo ""
echo "New state contents:"
terragrunt state list

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Next steps:"
echo "  1. Run: terragrunt plan"
echo "  2. Verify no destructive changes"
echo "  3. If satisfied, delete: rm -rf ../../../terraform/proxmox"
echo ""
echo "Old state still exists at Consul path: $OLD_CONSUL_PATH"
