# -----------------------------------------------------------------------------
# GOSSIP-KEYS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "keys" {
  description = "Map of key name to its generation options. The name is the Vault secret name a consumer reads. Serf wants 32 bytes."
  type = map(object({
    byte_length = optional(number, 32)
  }))
  default = {}
}
