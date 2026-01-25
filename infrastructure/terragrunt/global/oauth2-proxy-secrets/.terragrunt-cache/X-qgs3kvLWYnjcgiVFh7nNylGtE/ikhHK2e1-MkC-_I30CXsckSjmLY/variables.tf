# -----------------------------------------------------------------------------
# OAUTH2-PROXY SECRETS MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "vault_mount" {
  description = "Vault KV v2 mount path"
  type        = string
  default     = "secret"
}

variable "client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
}

variable "allowed_emails" {
  description = "List of email addresses allowed to authenticate"
  type        = list(string)
}

variable "cookie_secret" {
  description = "Existing cookie secret to preserve (base64-encoded). If null, generates a new one."
  type        = string
  default     = null
  sensitive   = true
}
