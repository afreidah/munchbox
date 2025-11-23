# Create policy file: infra/vault-policy/traefik-read.hcl
path "kv/data/traefik" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read", "sudo", "list"]
}
