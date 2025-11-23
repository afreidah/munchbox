# Create policy file: infra/vault-policy/github-runner-read.hcl
path "kv/data/github/runner" {
  capabilities = ["read"]
}
