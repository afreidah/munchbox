# -------------------------------------------------------------------------------
# Consul ACL Configuration - Outputs
# -------------------------------------------------------------------------------

output "policies_created" {
  description = "List of ACL policies created"
  value = [
    consul_acl_policy.nomad_server.name,
    consul_acl_policy.nomad_client.name,
    consul_acl_policy.vault_storage.name,
  ]
}

output "tokens_stored_in_vault" {
  description = "Vault KV paths where tokens are stored"
  value = {
    bootstrap    = "secret/consul/bootstrap-token"
    nomad_server = "secret/consul/nomad-server-token"
    nomad_client = "secret/consul/nomad-client-token"
    vault        = "secret/consul/vault-storage-token"
  }
}
