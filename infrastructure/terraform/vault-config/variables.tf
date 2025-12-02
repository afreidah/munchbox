# -------------------------------------------------------------------------------
# Vault Configuration - Variables
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

variable "consul_bootstrap_token" {
  description = "Consul ACL bootstrap token"
  type        = string
  sensitive   = true
}

variable "configure_database_engine" {
  description = "Configure database secrets engine (requires Postgres running)"
  type        = bool
  default     = true
}
