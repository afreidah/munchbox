# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS MODULE
# -----------------------------------------------------------------------------
#
# Syncs credentials from HashiCorp Vault to Vaultwarden for human access.
# Reads secrets from Vault and creates corresponding items.
#
# Components Created:
#   - Vaultwarden folders
#   - Vaultwarden login items (populated from Vault secrets)
#   - Vaultwarden secure note items (populated from Vault secrets)
#
# Architecture:
#   - Reads secrets from Vault using data sources
#   - Creates folders, login items, and secure notes in Vaultwarden
#   - Mapping between Vault paths and Vaultwarden items defined via inputs
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VAULT SECRETS
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "secrets" {
  for_each = var.login_items

  mount = var.vault_mount
  name  = each.value.vault_path
}

# -----------------------------------------------------------------------------
# FOLDERS
# -----------------------------------------------------------------------------

resource "bitwarden_folder" "folders" {
  for_each = var.folders

  name = each.value
}

# -----------------------------------------------------------------------------
# LOGIN ITEMS
# -----------------------------------------------------------------------------

resource "bitwarden_item_login" "logins" {
  for_each = var.login_items

  name      = each.value.name
  folder_id = each.value.folder_key != null ? bitwarden_folder.folders[each.value.folder_key].id : null
  username  = each.value.username_field != null ? data.vault_kv_secret_v2.secrets[each.key].data[each.value.username_field] : null
  password  = data.vault_kv_secret_v2.secrets[each.key].data[each.value.password_field]

  uri {
    value = each.value.uri
  }

  notes = lookup(each.value, "notes", "Synced from HashiCorp Vault")
}

# -----------------------------------------------------------------------------
# SECURE NOTE ITEMS
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "secure_notes" {
  for_each = var.secure_note_items

  mount = var.vault_mount
  name  = each.value.vault_path
}

resource "bitwarden_item_secure_note" "secure_notes" {
  for_each = var.secure_note_items

  name      = each.value.name
  folder_id = each.value.folder_key != null ? bitwarden_folder.folders[each.value.folder_key].id : null
  notes = join("\n\n", [
    lookup(each.value, "notes", "Synced from HashiCorp Vault"),
    data.vault_kv_secret_v2.secure_notes[each.key].data[each.value.content_field],
  ])
}
