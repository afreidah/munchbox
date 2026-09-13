# -----------------------------------------------------------------------------
# PASSWORDS MODULE
# -----------------------------------------------------------------------------
#
# Generates a password per field of each named secret. Vault-free: the values
# are a sensitive vault_data output written to Vault by the vault-secrets leaf.
#
# A value some other system already issued is adopted with
# `terraform import <addr> "<value>"`, which is why the generation args are
# ignored -- import resets them to schema defaults, and acting on that would
# rotate a credential the issuing system still expects.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  # --- one for_each key per field; the import address is
  #     random_password.this["<secret name>/<field>"] ---
  fields = merge([
    for name, fields in var.passwords : {
      for field, opts in fields : "${name}/${field}" => opts
    }
  ]...)
}

resource "random_password" "this" {
  for_each = local.fields

  length  = each.value.length
  special = each.value.special

  lifecycle {
    ignore_changes = [length, lower, upper, numeric, special, min_lower, min_upper, min_numeric, min_special]
  }
}
