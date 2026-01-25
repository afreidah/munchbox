# Health check policy - allows service health checks and Vault startup operations
service_prefix "" {
  policy = "read"
}
node_prefix "" {
  policy = "read"
}
key_prefix "vault" {
  policy = "read"
}
