#!/bin/bash
# -------------------------------------------------------------------------------
# Setup Terraform Environment Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Source this file to set up environment for Terraform:
#   source ./setup-env.sh
# -------------------------------------------------------------------------------

# Ensure we have the bootstrap token locally
if [ ! -f bootstrap-token.json ]; then
  echo "ERROR: bootstrap-token.json not found. Run ./bootstrap-acls.sh first."
  return 1
fi

# Get tokens
export CONSUL_HTTP_TOKEN=$(jq -r .secret_id bootstrap-token.json)
export CONSUL_HTTP_ADDR="https://192.168.68.61:8501"
export CONSUL_CACERT="${HOME}/.munchbox/ca-chain.crt"

# Fetch Vault root token from stabler
echo "Fetching Vault token from stabler..."
export VAULT_TOKEN=$(ssh root@stabler 'jq -r .root_token /tmp/vault-init.json')
export VAULT_ADDR="http://192.168.68.61:8200"
export VAULT_SKIP_VERIFY="true"

echo ""
echo "==> Environment configured:"
echo "CONSUL_HTTP_ADDR:  $CONSUL_HTTP_ADDR"
echo "CONSUL_CACERT:     $CONSUL_CACERT"
echo "VAULT_ADDR:        $VAULT_ADDR"
echo ""
echo "==> Ready to run Terraform!"
