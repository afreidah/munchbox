# Allow reading the docker registry password
path "kv/data/docker-registry" {
  capabilities = ["read"]
}
