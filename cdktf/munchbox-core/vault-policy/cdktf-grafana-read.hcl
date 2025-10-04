# KV v2: allow reads of grafana secrets and listing the prefix
path "secret/data/grafana"       { capabilities = ["read"] }
path "secret/data/grafana/*"     { capabilities = ["read"] }
path "secret/metadata/grafana"   { capabilities = ["list"] }
path "secret/metadata/grafana/*" { capabilities = ["list"] }
