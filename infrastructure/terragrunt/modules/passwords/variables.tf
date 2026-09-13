# -----------------------------------------------------------------------------
# PASSWORDS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "passwords" {
  description = "Map of Vault secret name to its fields, each with generation options. The name is the secret a consumer reads and the index into vault_data; the inner keys are that secret's Vault data keys."
  type = map(map(object({
    length  = optional(number, 32)
    special = optional(bool, true)
  })))
  default = {}
}
