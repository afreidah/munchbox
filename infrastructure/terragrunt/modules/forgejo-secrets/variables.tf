# -----------------------------------------------------------------------------
# FORGEJO SECRETS MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
}

variable "repository_owner" {
  description = "Owner of the Forgejo repository (user or organization)"
  type        = string
}

variable "repository_name" {
  description = "Name of the Forgejo repository"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to sync from Vault to Forgejo"
  type = map(object({
    vault_path  = string # Path in Vault KV (e.g., "aptly")
    vault_field = string # Field name in Vault secret (e.g., "password")
    secret_name = string # Name of the secret in Forgejo (e.g., "APTLY_PASS")
  }))
  default = {}
}
