# -----------------------------------------------------------------------------
# PASSWORDS Module Outputs
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Per-secret Vault-ready data: { <name> = { <field> = password } }. Consumed by the vault-secrets leaf, indexed by name."
  # try() tolerates partial state during incremental `terraform import` -- the
  # output is evaluated on every import, before all instances exist.
  value = {
    for name, fields in var.passwords : name => {
      for field, _ in fields : field => try(random_password.this["${name}/${field}"].result, null)
    }
  }
  sensitive = true
}
