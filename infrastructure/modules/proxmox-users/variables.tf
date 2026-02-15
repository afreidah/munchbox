# -----------------------------------------------------------------------------
# PROXMOX-USERS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
}

variable "roles" {
  description = "Map of custom roles to create"
  type = map(object({
    privileges = list(string)
  }))
  default = {}
}

variable "users" {
  description = "Map of users to create with their ACLs"
  type = map(object({
    user_id            = string
    password           = optional(string)
    vault_path         = optional(string)
    vault_password_key = optional(string, "password")
    comment            = optional(string)
    enabled            = optional(bool)
    acls = optional(list(object({
      path      = string
      role_id   = string
      propagate = optional(bool)
    })))
  }))
  default = {}
}
