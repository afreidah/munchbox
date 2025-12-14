# -------------------------------------------------------------------------------
# Google OAuth Configuration - Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable definitions for Google Cloud OAuth consent screen configuration. The
# support email appears on the OAuth consent screen shown to users.
# -------------------------------------------------------------------------------

variable "support_email" {
  description = "Support email for OAuth consent screen"
  type        = string
  default     = "alex.freidah@gmail.com"
}
