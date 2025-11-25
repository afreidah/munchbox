#!/bin/bash
# -------------------------------------------------------------------------------
# Consul ACL Bootstrap Script
#
# Project: Munchbox / Author: Alex Freidah
#
# One-time bootstrap of Consul ACLs. Run this before terraform apply.
# -------------------------------------------------------------------------------

set -e

echo "==> Bootstrapping Consul ACLs..."

# Bootstrap ACLs (only works once)
BOOTSTRAP_OUTPUT=$(consul acl bootstrap \
  -http-addr=https://192.168.68.61:8501 \
  -ca-file=/etc/consul.d/tls/ca-chain.crt \
  -format=json 2>&1)

if echo "$BOOTSTRAP_OUTPUT" | grep -q "ACL bootstrap no longer allowed"; then
  echo "ERROR: ACLs already bootstrapped. Retrieve the bootstrap token from Vault."
  exit 1
fi

# Parse the bootstrap token
BOOTSTRAP_TOKEN=$(echo "$BOOTSTRAP_OUTPUT" | jq -r '.SecretID')

echo ""
echo "==> Bootstrap successful!"
echo ""
echo "Bootstrap Token: $BOOTSTRAP_TOKEN"
echo ""
echo "CRITICAL: Save this token securely!"
echo ""
echo "Next steps:"
echo "  1. export CONSUL_HTTP_TOKEN=\"$BOOTSTRAP_TOKEN\""
echo "  2. export VAULT_TOKEN=\$(cat /tmp/vault-init.json | jq -r '.root_token')"
echo "  3. cd terraform/consul-acls"
echo "  4. terraform init"
echo "  5. terraform apply -var=\"consul_bootstrap_token=$BOOTSTRAP_TOKEN\""
