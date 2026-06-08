# -----------------------------------------------------------------------------
# ACCESS-KEYS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "credentials" {
  description = "Map of credential name to its generation options. The name is the Vault secret name / index a consumer reads. Lengths default to S3-style (20-char id, 40-char secret) but any consumer can override."
  type = map(object({
    id_length     = optional(number, 20)
    secret_length = optional(number, 40)
  }))
  default = {}
}
