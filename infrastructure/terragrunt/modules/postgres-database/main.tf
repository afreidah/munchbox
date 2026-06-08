# -----------------------------------------------------------------------------
# POSTGRES DATABASE MODULE
# -----------------------------------------------------------------------------
#
# Owns each app's Postgres login role plus the databases that role owns,
# idempotent on every apply. Vault KV is the credential source apps read: with
# manage_secret=true this module generates a password and seeds Vault for a new
# app; with manage_secret=false it adopts the existing Vault creds (no rotation)
# so running apps are untouched. Per-database extensions are flattened and
# ensured via for_each.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# --- adopt: read current creds from Vault (source of truth, no rotation) ---
data "vault_kv_secret_v2" "existing" {
  count = var.manage_secret ? 0 : 1
  mount = "secret"
  name  = var.vault_kv_path
}

# --- new app: generate a password and seed Vault under the same path apps read ---
resource "random_password" "role" {
  count   = var.manage_secret ? 1 : 0
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "creds" {
  count = var.manage_secret ? 1 : 0
  mount = "secret"
  name  = var.vault_kv_path
  data_json = jsonencode({
    (var.username_field) = var.app
    (var.password_field) = random_password.role[0].result
  })
}

locals {
  role     = var.manage_secret ? var.app : data.vault_kv_secret_v2.existing[0].data[var.username_field]
  password = var.manage_secret ? random_password.role[0].result : data.vault_kv_secret_v2.existing[0].data[var.password_field]
}

resource "postgresql_role" "app" {
  name     = local.role
  login    = true
  password = local.password
}

resource "postgresql_database" "db" {
  for_each = toset(var.databases)

  name  = each.value
  owner = postgresql_role.app.name

  lifecycle {
    # --- immutable/ForceNew fields read at import time; never recreate a data-bearing DB ---
    ignore_changes  = [encoding, lc_collate, lc_ctype, template, allow_connections, connection_limit, is_template]
    prevent_destroy = true
  }
}

# --- flatten { db = [ext, ...] } into "db/ext" => {db, name} pairs ---
locals {
  extension_pairs = merge([
    for db, exts in var.extensions : {
      for e in exts : "${db}/${e}" => { database = db, name = e }
    }
  ]...)
}

resource "postgresql_extension" "this" {
  for_each = local.extension_pairs

  name     = each.value.name
  database = postgresql_database.db[each.value.database].name
}
