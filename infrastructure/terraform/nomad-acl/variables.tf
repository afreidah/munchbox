# -------------------------------------------------------------------------------
# Variables
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

variable "nomad_address" {
  description = "Nomad API address"
  type        = string
  default     = "https://192.168.68.61:4646"
}

variable "nomad_token" {
  description = "Nomad management token (bootstrap token)"
  type        = string
  sensitive   = true
}

variable "vault_address" {
  description = "Vault API address"
  type        = string
  default     = "http://192.168.68.61:8200"
}

variable "vault_token" {
  description = "Vault token with write access to secrets"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# External Tokens
# -----------------------------------------------------------------------------

variable "backup_consul_token" {
  description = "Consul token for backup-worker (if managing externally)"
  type        = string
  default     = ""
  sensitive   = true
}
