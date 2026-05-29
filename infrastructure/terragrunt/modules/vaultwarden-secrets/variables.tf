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
# BITWARDEN PROVIDER AUTH
# -----------------------------------------------------------------------------

variable "bitwarden_server" {
  description = "Vaultwarden/Bitwarden server URL the provider talks to."
  type        = string
}

variable "bitwarden_email" {
  description = "Login email for the Vaultwarden account that owns the synced items."
  type        = string
}

variable "bitwarden_master_password" {
  description = "Master password; sourced from VAULTWARDEN_MASTER_PASSWORD via the env_helper."
  type        = string
  sensitive   = true
}

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
