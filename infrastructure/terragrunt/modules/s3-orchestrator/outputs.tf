# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR Module Outputs
# -----------------------------------------------------------------------------

output "user_ids" {
  description = "Map of identity name to the generated user id its credential and grant reference; a rename does not move it."
  value       = { for k, u in s3orchestrator_user.this : k => u.id }
}

output "access_key_ids" {
  description = "Map of identity name to the access key it authenticates with. Not sensitive: the key names a credential, it does not prove one."
  value       = { for k, c in s3orchestrator_credential.this : k => c.access_key_id }
}

output "credentials" {
  description = "Map of identity name to the keypair it authenticates with, for a consumer that reads its credential through terragrunt rather than out of Vault at run time."
  sensitive   = true
  value = {
    for k, c in s3orchestrator_credential.this : k => {
      access_key = c.access_key_id
      secret_key = c.secret_access_key
    }
  }
}

output "vault_paths" {
  description = "Map of identity name to the Vault KV path its keypair was written to, for pointing a job's template at it."
  value       = { for k, s in vault_kv_secret_v2.identity : k => "${var.vault_mount}/${s.name}" }
}
