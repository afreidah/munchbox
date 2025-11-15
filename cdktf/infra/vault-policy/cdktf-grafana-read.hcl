# KV v2: allow reads of grafana secrets and listing the prefix
path "kv/data/grafana"       { capabilities = ["read"] }
path "kv/data/grafana/*"     { capabilities = ["read"] }
path "kv/metadata/grafana"   { capabilities = ["list"] }
path "kv/metadata/grafana/*" { capabilities = ["list"] }
