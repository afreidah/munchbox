# cdktf-grafana-read.hcl
# KV v2: allow reads of grafana secrets and listing the prefix

# Read the actual secret data
path "kv/data/grafana" {
  capabilities = ["read"]
}

path "kv/data/grafana/*" {
  capabilities = ["read"]
}

# List metadata under the grafana prefix
path "kv/metadata/grafana" {
  capabilities = ["list", "read"]
}

path "kv/metadata/grafana/*" {
  capabilities = ["list", "read"]
}

