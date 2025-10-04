# Create policy file: infra/vault-policy/deluge-read.hcl
path "kv/data/deluge" {
  capabilities = ["read"]
}
