# KV v2: data + metadata + allow the trailing-slash preflight
path "secret/data/grafana"      { capabilities = ["read"] }
path "secret/data/grafana/*"    { capabilities = ["read"] }
path "secret/metadata/grafana"  { capabilities = ["read"] }
path "secret/metadata/grafana/*"{ capabilities = ["read"] }
