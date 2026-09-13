# -----------------------------------------------------------------------------
# CINC-SERVER-KEYS Module Outputs
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Per-user Vault-ready data: { <username> = { password, private_key, public_key } }. Consumed by the vault-secrets leaf, indexed by username."
  value = {
    for name in keys(var.users) : name => {
      password    = random_password.user[name].result
      private_key = tls_private_key.user[name].private_key_pem
      public_key  = tls_private_key.user[name].public_key_pem
    }
  }
  sensitive = true
}
