#!/bin/bash
# -------------------------------------------------------------------------------
# Fix Vault Consul Connection
#
# Project: Munchbox / Author: Alex Freidah
#
# Updates Vault configuration to use HTTP:8500 instead of HTTPS:8501 for Consul,
# since Consul TLS is not enabled yet.
# -------------------------------------------------------------------------------

set -e

VAULT_SERVERS="stabler goren nomad-server-03"

echo "==============================================================================="
echo "Fixing Vault -> Consul Connection"
echo "==============================================================================="
echo ""
echo "Problem: Vault is trying to connect to Consul on HTTPS:8501"
echo "         but Consul is only listening on HTTP:8500"
echo ""

for server in $VAULT_SERVERS; do
  echo "==> Fixing $server..."
  
  ssh root@$server bash << 'REMOTE_SCRIPT'
set -e

CONFIG="/etc/vault.d/vault.hcl"
BACKUP="/etc/vault.d/vault.hcl.bak.$(date +%Y%m%d%H%M%S)"

# Backup
cp "$CONFIG" "$BACKUP"
echo "Backed up to $BACKUP"

echo ""
echo "Current storage block:"
grep -A10 'storage "consul"' "$CONFIG" || echo "No storage block found"

# Fix the address and scheme in storage block
# Change 127.0.0.1:8501 -> 127.0.0.1:8500
# Change scheme = "https" -> scheme = "http"
sed -i 's|address\s*=\s*"127.0.0.1:8501"|address = "127.0.0.1:8500"|g' "$CONFIG"
sed -i 's|address\s*=\s*"https://127.0.0.1:8501"|address = "127.0.0.1:8500"|g' "$CONFIG"
sed -i 's|scheme\s*=\s*"https"|scheme  = "http"|g' "$CONFIG"

# Also check for any explicit service_registration block
if grep -q 'service_registration' "$CONFIG"; then
  sed -i '/service_registration/,/}/ s|address\s*=\s*"127.0.0.1:8501"|address = "127.0.0.1:8500"|g' "$CONFIG"
  sed -i '/service_registration/,/}/ s|scheme\s*=\s*"https"|scheme  = "http"|g' "$CONFIG"
fi

echo ""
echo "Updated storage block:"
grep -A10 'storage "consul"' "$CONFIG"
REMOTE_SCRIPT

  echo ""
done

echo "==============================================================================="
echo "Restarting Vault Servers (one at a time for HA safety)"
echo "==============================================================================="
echo ""

for server in $VAULT_SERVERS; do
  echo "==> Restarting Vault on $server..."
  ssh root@$server 'systemctl restart vault'
  
  echo "    Waiting 15 seconds for Vault to stabilize..."
  sleep 15
  
  echo "    Checking Vault status..."
  ssh root@$server 'VAULT_ADDR=http://127.0.0.1:8200 vault status 2>&1' || true
  echo ""
done

echo "==============================================================================="
echo "Verifying Health Checks"
echo "==============================================================================="
echo ""

echo "Waiting 20 seconds for TTL checks to update..."
sleep 20

echo ""
echo "Vault service health in Consul:"
ssh root@stabler "curl -s 'http://localhost:8500/v1/health/service/vault' | jq '.[].Checks[] | {Node: .Node, Status: .Status, Output: .Output[:80]}'"

echo ""
echo "==============================================================================="
echo "Done!"
echo "==============================================================================="
