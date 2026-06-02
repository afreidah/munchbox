# -----------------------------------------------------------------------------
# APTLY-SECRETS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "username" {
  description = "Basic-auth username for the aptly API; embedded in the htpasswd line."
  type        = string
  default     = "admin"
}
