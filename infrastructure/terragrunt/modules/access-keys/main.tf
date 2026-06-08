# -----------------------------------------------------------------------------
# ACCESS-KEYS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Generates an access-key / secret-key credential pair per map entry. Vault-
# free: the pairs are sensitive outputs written to Vault by the vault-secrets
# leaf. Existing keys are adopted without rotation by importing the random
# resources with their current values (terraform import <addr> "<value>").
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ACCESS KEY ID (public half) - uppercase alphanumeric, AWS-shaped
# -----------------------------------------------------------------------------

resource "random_string" "access_key" {
  for_each = var.credentials

  length  = each.value.id_length
  special = false
  lower   = false
  upper   = true
  numeric = true

  # Import adopts existing keys without rotation: `terraform import` records the
  # value but resets the generation args to schema defaults in state, which
  # would otherwise force a replace. Ignoring them keeps imported keys stable
  # for any shape; new keys still generate with the args above.
  lifecycle {
    ignore_changes = [length, lower, upper, numeric, special, min_lower, min_upper, min_numeric, min_special]
  }
}

# -----------------------------------------------------------------------------
# SECRET ACCESS KEY (private half) - alphanumeric to stay config/escaping-safe
# -----------------------------------------------------------------------------

resource "random_password" "secret_key" {
  for_each = var.credentials

  length  = each.value.secret_length
  special = false

  # See random_string.access_key above: keep imported secrets stable.
  lifecycle {
    ignore_changes = [length, lower, upper, numeric, special, min_lower, min_upper, min_numeric, min_special]
  }
}
