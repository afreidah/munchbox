# Read and list all secrets, but no write or admin actions
path "secret/data/*" {
  capabilities = ["read", "list"]
}

# Allow reading policies (optional)
path "sys/policies/acl" {
  capabilities = ["read", "list"]
}
