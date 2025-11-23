# Policy for taking OpenBao/Vault snapshots
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
