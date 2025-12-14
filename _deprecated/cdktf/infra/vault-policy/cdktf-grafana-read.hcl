# -------------------------------------------------------------------------------
# Grafana Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Grafana read access to its secrets in KV v2 for datasource credentials.
# -------------------------------------------------------------------------------

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

