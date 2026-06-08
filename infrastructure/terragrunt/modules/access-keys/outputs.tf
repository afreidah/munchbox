# -----------------------------------------------------------------------------
# ACCESS-KEYS Module Outputs
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Per-name Vault-ready data: { <name> = { access_key, secret_key } }. Consumed by the vault-secrets leaf, indexed by name."
  # try() tolerates partial state during incremental `terraform import` -- the
  # output is evaluated on every import, before all instances exist. After a
  # full apply every for_each instance is present, so values are never null.
  value = {
    for name in keys(var.credentials) : name => {
      access_key = try(random_string.access_key[name].result, null)
      secret_key = try(random_password.secret_key[name].result, null)
    }
  }
  sensitive = true
}
