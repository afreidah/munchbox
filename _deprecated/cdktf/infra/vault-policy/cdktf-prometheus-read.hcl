# Create policy file: infra/vault-policy/cdktf-prometheus-read.hcl
path "kv/data/prometheus" {
  capabilities = ["read"]
}
