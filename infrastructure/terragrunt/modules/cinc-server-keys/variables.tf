# -----------------------------------------------------------------------------
# CINC-SERVER-KEYS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "users" {
  description = "Map of cinc-server username to its generation options. The key is the username the server knows and the index a consumer reads out of vault_data."
  type = map(object({
    password_length = optional(number, 32)
    rsa_bits        = optional(number, 2048)
  }))
  default = {}
}
