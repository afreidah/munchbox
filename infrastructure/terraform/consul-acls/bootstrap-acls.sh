#!/bin/bash
# -------------------------------------------------------------------------------
# Consul ACL Bootstrap Helper
#
# Project: Munchbox / Author: Alex Freidah
#
# Run this from your LOCAL machine. It SSHs to stabler to bootstrap Consul ACLs.
# -------------------------------------------------------------------------------

set -e

echo "==> Bootstrapping Consul ACLs on stabler..."
echo ""

# SSH to stabler and run the bootstrap command
BOOTSTRAP_JSON=$(ssh root@stabler "consul acl bootstrap -format=json 2>&1" || true)

if echo "$BOOTSTRAP_JSON" | grep -q "ACL bootstrap no longer allowed"; then
  echo "ERROR: ACLs already bootstrapped."
  echo ""
  echo "Retrieve the bootstrap token from Vault:"
  echo "  ssh root@stabler 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=\$(jq -r .root_token /tmp/vault-init.json) vault kv get -field=token secret/consul/bootstrap-token'"
  exit 1
fi

# Parse the bootstrap token
BOOTSTRAP_TOKEN=$(echo "$BOOTSTRAP_JSON" | jq -r '.SecretID')
ACCESSOR_ID=$(echo "$BOOTSTRAP_JSON" | jq -r '.AccessorID')

echo "==> Bootstrap successful!"
echo ""
echo "SecretID:   $BOOTSTRAP_TOKEN"
echo "AccessorID: $ACCESSOR_ID"
echo ""
echo "==> Saving to local file..."

# Save to local file
cat > bootstrap-token.json << EOT
{
  "secret_id": "$BOOTSTRAP_TOKEN",
  "accessor_id": "$ACCESSOR_ID",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOT

echo "Saved to: $(pwd)/bootstrap-token.json"
echo ""
echo "==> Next steps:"
echo "  1. Enable Vault KV v2:"
echo "     ssh root@stabler 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=\$(jq -r .root_token /tmp/vault-init.json) vault secrets enable -path=secret kv-v2'"
echo ""
echo "  2. Set environment variables:"
echo "     export CONSUL_HTTP_TOKEN=\"$BOOTSTRAP_TOKEN\""
echo "     export CONSUL_HTTP_ADDR=\"https://192.168.68.61:8501\""
echo "     export CONSUL_CACERT=\"/etc/consul.d/tls/ca-chain.crt\""
echo "     export VAULT_TOKEN=\$(ssh root@stabler 'jq -r .root_token /tmp/vault-init.json')"
echo "     export VAULT_ADDR=\"http://192.168.68.61:8200\""
echo ""
echo "  3. Run Terraform:"
echo "     cd terraform/consul-acls"
echo "     terraform init"
echo "     terraform apply -var=\"consul_bootstrap_token=$BOOTSTRAP_TOKEN\""
