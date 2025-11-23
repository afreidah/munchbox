# Create policy file for consul-snapshot
path "kv/data/consul-snapshot" {
  capabilities = ["read"]
}
