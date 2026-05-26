# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Variable Categories:
#   - Vault: Vault connection settings
#   - Folders: Vaultwarden folder definitions
#   - Logins: Login item mappings
#   - Secure Notes: Secure note item mappings
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VAULT
# -----------------------------------------------------------------------------

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
}

# -----------------------------------------------------------------------------
# FOLDERS
# -----------------------------------------------------------------------------

variable "folders" {
  description = "Map of folder keys to folder names"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# LOGIN ITEMS
# -----------------------------------------------------------------------------

variable "login_items" {
  description = "Map of login items to sync from Vault to Vaultwarden"
  type = map(object({
    name           = string
    uri            = string
    vault_path     = string
    password_field = string
    username_field = optional(string)
    folder_key     = optional(string)
    notes          = optional(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# SECURE NOTE ITEMS
# -----------------------------------------------------------------------------

variable "secure_note_items" {
  description = "Map of secure note items to sync from Vault to Vaultwarden"
  type = map(object({
    name          = string
    vault_path    = string
    content_field = string
    folder_key    = optional(string)
    notes         = optional(string)
  }))
  default = {}
}
