# -----------------------------------------------------------------------------
# VAULT-KV-SECRETS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "secrets" {
  description = "Map of secret name to its KV v2 mount and key/value data. Each entry owns the whole key map at its path."
  type = map(object({
    mount = optional(string, "secret")
    data  = map(string)
  }))
}
