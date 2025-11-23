# Policy for temporal-backup-worker to read static Nomad token
path "kv/data/backup-worker" {
  capabilities = ["read"]
}
